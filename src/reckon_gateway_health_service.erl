%% @doc gRPC HealthService implementation (emqx/grpc-erl).
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
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:quick_health_check(StoreId) of
                {ok, _} ->
                    {ok, #{status => 'HEALTH_STATUS_HEALTHY', details => #{}}, Md};
                {error, _} ->
                    {ok, #{status => 'HEALTH_STATUS_UNHEALTHY', details => #{}}, Md}
            end
    end.

health(#{}, Md) ->
    case reckon_gater_api:health() of
        {ok, #{status := Status} = Info} ->
            ProtoStatus = case Status of
                healthy -> 'HEALTH_STATUS_HEALTHY';
                degraded -> 'HEALTH_STATUS_DEGRADED';
                _ -> 'HEALTH_STATUS_UNHEALTHY'
            end,
            Stores = maps:fold(
                fun(K, V, Acc) -> Acc#{atom_to_binary(K, utf8) => V} end,
                #{}, maps:get(stores, Info, #{})),
            {ok, #{status => ProtoStatus,
                   stores => Stores,
                   total_workers => maps:get(total_workers, Info, 0),
                   node => atom_to_binary(maps:get(node, Info, node()), utf8),
                   timestamp => maps:get(timestamp, Info, 0)}, Md};
        _ ->
            {ok, #{status => 'HEALTH_STATUS_UNHEALTHY',
                   stores => #{}, total_workers => 0,
                   node => atom_to_binary(node(), utf8),
                   timestamp => erlang:system_time(millisecond)}, Md}
    end.

verify_cluster_consistency(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:verify_cluster_consistency(StoreId) of
                {ok, #{status := Status} = Info} ->
                    {ok, #{status => cluster_status(Status), details => maps_to_strings(Info)}, Md};
                {error, _} -> {error, <<"13">>}
            end
    end.

verify_membership_consensus(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:verify_membership_consensus(StoreId) of
                {ok, #{status := Status} = Info} ->
                    {ok, #{status => cluster_status(Status), details => maps_to_strings(Info)}, Md};
                {error, _} -> {error, <<"13">>}
            end
    end.

check_raft_log_consistency(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:check_raft_log_consistency(StoreId) of
                {ok, #{status := Status} = Info} ->
                    {ok, #{status => cluster_status(Status), details => maps_to_strings(Info)}, Md};
                {error, _} -> {error, <<"13">>}
            end
    end.

get_memory_level(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:get_memory_level(StoreId) of
                {ok, Level} ->
                    ProtoLevel = case Level of
                        low -> 'MEMORY_LEVEL_LOW'; normal -> 'MEMORY_LEVEL_NORMAL';
                        high -> 'MEMORY_LEVEL_HIGH'; critical -> 'MEMORY_LEVEL_CRITICAL';
                        _ -> 'MEMORY_LEVEL_NORMAL'
                    end,
                    {ok, #{level => ProtoLevel}, Md};
                {error, _} -> {error, <<"13">>}
            end
    end.

get_memory_stats(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:get_memory_stats(StoreId) of
                {ok, Stats} ->
                    {ok, #{used_bytes => maps:get(used, Stats, 0),
                           total_bytes => maps:get(total, Stats, 0),
                           usage_percent => maps:get(usage_percent, Stats, 0.0),
                           breakdown => maps_to_strings(maps:get(breakdown, Stats, #{}))}, Md};
                {error, _} -> {error, <<"13">>}
            end
    end.

%% @doc GetServerInfo — advertise the tamper-resistance algorithm,
%% per-store integrity status, and version information so polyglot
%% clients can verify chain hashes locally with confidence.
%%
%% Important: the HMAC key itself is NEVER returned. Only the key ID
%% (an opaque integer the server uses to coordinate rotation) appears
%% in the response.
get_server_info(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            IntegrityEnabled = integrity_enabled_for_store(StoreId),
            {AlgoBin, KeyId} = case IntegrityEnabled of
                true ->
                    %% Key ID is fixed at 1 in reckon-db 2.1.0; rotation
                    %% machinery (2.2+) will introduce variable IDs.
                    {?INTEGRITY_ALGO, 1};
                false ->
                    {<<>>, 0}
            end,
            {ok, #{
                reckon_db_version => reckon_db_version(),
                reckon_gateway_version => reckon_gateway_version(),
                integrity_algo => AlgoBin,
                integrity_enabled => IntegrityEnabled,
                hmac_key_id => KeyId,
                api_compatibility_version => ?API_COMPAT_VERSION
            }, Md}
    end.

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
