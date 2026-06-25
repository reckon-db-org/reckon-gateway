%% @doc gRPC HealthService implementation (emqx/grpc-erl).
%%
%% Error paths routed through reckon_gateway_error so the
%% underlying reason is logged server-side (grpc-erl drops
%% grpc-message on unary; see reckon_gateway_error docstring).
%%
%% Note: `check/2' deliberately does NOT raise gRPC errors on
%% dispatch failure — instead it returns a HEALTHY/UNHEALTHY
%% Health response. The dispatch failure IS the answer to
%% "is this store healthy?". That non-error path is left intact;
%% we log the dispatch reason directly so docker logs still
%% carry it.
-module(reckon_gateway_health_service).

-export([
    check/2, health/2,
    verify_cluster_consistency/2, verify_membership_consensus/2,
    check_raft_log_consistency/2,
    get_memory_level/2, get_memory_stats/2,
    get_server_info/2
]).

%% The canonical algorithm identifier for chain-hash verification
%% in reckon-gateway 0.2.0. See reckon_gater_canonical and
%% reckon_gater_integrity for the matching server-side implementation.
%% Bumped when the canonical encoding or hash function changes.
-define(INTEGRITY_ALGO, <<"sha256-deterministic-etf-v1">>).

%% Bumped on breaking proto changes so polyglot clients can detect
%% incompatibility at handshake rather than via failed RPCs.
-define(API_COMPAT_VERSION, <<"reckon.gateway.v1">>).

check(#{store_id := StoreIdBin}, Md) ->
    with_store_id(StoreIdBin, check,
        fun(StoreId) -> check_mode(single_mode_short_circuit(StoreId), StoreId, Md) end).

check_mode(true, _StoreId, Md) ->
    {ok, #{status => 'HEALTH_STATUS_HEALTHY', details => #{<<"mode">> => <<"single">>}}, Md};
check_mode(false, StoreId, Md) ->
    check_result(reckon_gateway_dispatch:call(quick_health_check, [StoreId]), Md).

check_result({ok, _}, Md) ->
    {ok, #{status => 'HEALTH_STATUS_HEALTHY', details => #{}}, Md};
check_result({error, Reason}, Md) ->
    %% Dispatch failure IS the answer — return UNHEALTHY, not a gRPC
    %% error. Still log the reason for triage.
    reckon_gateway_error:log(check, <<"unhealthy">>, Reason),
    {ok, #{status => 'HEALTH_STATUS_UNHEALTHY', details => #{}}, Md}.

health(#{}, Md) ->
    %% Catalogue-mode gateway: this is the GATEWAY's own health, NOT
    %% any per-store BEAM's. Inheriting from the pre-catalogue
    %% (data-plane) handler, this used to dispatch `health' with an
    %% empty arg list which now crashes the dispatcher
    %% (pattern requires `[StoreId | _]'). Compute the gateway's
    %% status from the catalogue instead — no BEAM round-trip required.
    Snapshot = reckon_gateway_catalogue:status(),
    Clusters = maps:get(clusters, Snapshot, []),
    Status = health_status(Clusters),
    %% `stores' is `map<string, uint32>' in the proto (per-cluster
    %% store count). cluster_id binary -> store_count int.
    StoresMap = lists:foldl(fun store_count_acc/2, #{}, Clusters),
    {ok, #{status => Status,
           stores => StoresMap,
           total_workers => maps:get(catalogue_size, Snapshot, 0),
           node => atom_to_binary(node(), utf8),
           timestamp => erlang:system_time(millisecond)}, Md}.

%% @private No connectors configured at all means the gateway is up
%% but has nothing to route to.
health_status([]) ->
    'HEALTH_STATUS_DEGRADED';
health_status(Clusters) ->
    health_status_any(lists:any(fun cluster_up/1, Clusters)).

health_status_any(true)  -> 'HEALTH_STATUS_HEALTHY';
health_status_any(false) -> 'HEALTH_STATUS_DEGRADED'.

cluster_up(#{status := up}) -> true;
cluster_up(_)               -> false.

store_count_acc(#{cluster_id := CId, store_count := SC}, Acc) ->
    Acc#{atom_to_binary(CId, utf8) => SC}.

%% @private Resolve a store-id binary, wrapping the canonical
%% invalid_store_id gRPC error, then run Fun with the parsed id.
with_store_id(StoreIdBin, ErrFn, Fun) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(ErrFn, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            Fun(StoreId)
    end.

verify_cluster_consistency(#{store_id := StoreIdBin}, Md) ->
    raft_only_check(StoreIdBin, verify_cluster_consistency, Md).

verify_membership_consensus(#{store_id := StoreIdBin}, Md) ->
    raft_only_check(StoreIdBin, verify_membership_consensus, Md).

check_raft_log_consistency(#{store_id := StoreIdBin}, Md) ->
    raft_only_check(StoreIdBin, check_raft_log_consistency, Md).

%% @private Cluster-only consistency RPCs. Single-mode reckon-db has
%% no Raft and no `reckon_db_cluster' module loaded; dispatching the
%% RPC to the BEAM that holds the single-mode store triggers
%% `{undef, reckon_db_cluster:..}' and a retry storm in the
%% reckon-gater 1.x with_retry wrapper (~155s of back-off per call).
%% That storm blocks the worker gen_server and starves concurrent
%% list_streams / read_stream_forward calls, surfacing as `INTERNAL'
%% errors in clients (lazyreckon).
%%
%% Short-circuit here: if the catalogue marks the store as single
%% mode, the answer is unambiguous — there is nothing to verify — so
%% return HEALTHY with a mode=single detail instead of touching the
%% BEAM at all.
raft_only_check(StoreIdBin, DispatchFn, Md) ->
    with_store_id(StoreIdBin, DispatchFn,
        fun(StoreId) -> raft_mode(single_mode_short_circuit(StoreId), StoreId, DispatchFn, Md) end).

raft_mode(true, _StoreId, _DispatchFn, Md) ->
    {ok, #{status  => 'CLUSTER_STATUS_HEALTHY',
           details => #{<<"mode">>   => <<"single">>,
                        <<"reason">> => <<"no cluster to verify">>}}, Md};
raft_mode(false, StoreId, DispatchFn, Md) ->
    raft_reply(reckon_gateway_dispatch:call(DispatchFn, [StoreId]), DispatchFn, Md).

raft_reply({ok, #{status := Status} = Info}, _DispatchFn, Md) ->
    {ok, #{status => cluster_status(Status), details => maps_to_strings(Info)}, Md};
raft_reply({error, Reason}, DispatchFn, _Md) ->
    reckon_gateway_error:wrap(DispatchFn, <<"13">>, Reason).

%% @private Returns true if the catalogue knows this store and it is
%% single-mode. False on unknown stores OR cluster-mode stores — in
%% both cases the dispatcher is the right next hop.
single_mode_short_circuit(StoreId) ->
    case reckon_gateway_catalogue:store_mode(StoreId) of
        {ok, single} -> true;
        _            -> false
    end.

get_memory_level(#{store_id := StoreIdBin}, Md) ->
    with_store_id(StoreIdBin, get_memory_level,
        fun(StoreId) ->
            memory_level_reply(reckon_gateway_dispatch:call(get_memory_level, [StoreId]), Md)
        end).

memory_level_reply({ok, Level}, Md) ->
    {ok, #{level => proto_memory_level(Level)}, Md};
memory_level_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(get_memory_level, <<"13">>, Reason).

proto_memory_level(low)      -> 'MEMORY_LEVEL_LOW';
proto_memory_level(normal)   -> 'MEMORY_LEVEL_NORMAL';
proto_memory_level(high)     -> 'MEMORY_LEVEL_HIGH';
proto_memory_level(critical) -> 'MEMORY_LEVEL_CRITICAL';
proto_memory_level(_)        -> 'MEMORY_LEVEL_NORMAL'.

get_memory_stats(#{store_id := StoreIdBin}, Md) ->
    with_store_id(StoreIdBin, get_memory_stats,
        fun(StoreId) ->
            memory_stats_reply(reckon_gateway_dispatch:call(get_memory_stats, [StoreId]), Md)
        end).

memory_stats_reply({ok, Stats}, Md) ->
    {ok, #{used_bytes => maps:get(used, Stats, 0),
           total_bytes => maps:get(total, Stats, 0),
           usage_percent => maps:get(usage_percent, Stats, 0.0),
           breakdown => maps_to_strings(maps:get(breakdown, Stats, #{}))}, Md};
memory_stats_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(get_memory_stats, <<"13">>, Reason).

%% @doc GetServerInfo — advertise the tamper-resistance algorithm,
%% per-store integrity status, and version information so polyglot
%% clients can verify chain hashes locally with confidence.
%%
%% Important: the HMAC key itself is NEVER returned. Only the key ID
%% (an opaque integer the server uses to coordinate rotation) appears
%% in the response.
get_server_info(#{store_id := StoreIdBin}, Md) ->
    with_store_id(StoreIdBin, get_server_info, fun(StoreId) -> server_info_reply(StoreId, Md) end).

server_info_reply(StoreId, Md) ->
    IntegrityEnabled = integrity_enabled_for_store(StoreId),
    {AlgoBin, KeyId} = integrity_advert(IntegrityEnabled),
    {ok, #{
        reckon_db_version => reckon_db_version(),
        reckon_gateway_version => reckon_gateway_version(),
        integrity_algo => AlgoBin,
        integrity_enabled => IntegrityEnabled,
        hmac_key_id => KeyId,
        api_compatibility_version => ?API_COMPAT_VERSION
    }, Md}.

%% @private Key ID is fixed at 1 in reckon-db 2.1.0; rotation
%% machinery (2.2+) will introduce variable IDs.
integrity_advert(true)  -> {?INTEGRITY_ALGO, 1};
integrity_advert(false) -> {<<>>, 0}.

%% @private Whether the addressed store has integrity enabled.
%% Wraps the local reckon_db check; falls back to `false` on errors
%% so a misconfigured gateway never advertises integrity that isn't
%% actually there.
integrity_enabled_for_store(StoreId) ->
    try reckon_db_integrity_key:is_enabled(StoreId)
    catch _:_ -> false
    end.

reckon_db_version() ->
    app_version(reckon_db).

reckon_gateway_version() ->
    app_version(reckon_gateway).

app_version(App) ->
    case application:get_key(App, vsn) of
        {ok, Vsn} when is_list(Vsn) -> list_to_binary(Vsn);
        _ -> <<"unknown">>
    end.

cluster_status(healthy) -> 'CLUSTER_STATUS_HEALTHY';
cluster_status(degraded) -> 'CLUSTER_STATUS_DEGRADED';
cluster_status(split_brain) -> 'CLUSTER_STATUS_SPLIT_BRAIN';
cluster_status(no_quorum) -> 'CLUSTER_STATUS_NO_QUORUM';
cluster_status(_) -> 'CLUSTER_STATUS_DEGRADED'.

maps_to_strings(Map) when is_map(Map) ->
    maps:fold(fun(K, V, Acc) ->
        Acc#{iolist_to_binary(io_lib:format("~p", [K])) =>
             iolist_to_binary(io_lib:format("~p", [V]))}
    end, #{}, Map);
maps_to_strings(_) -> #{}.
