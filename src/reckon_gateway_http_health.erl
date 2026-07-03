%%% @doc HTTP/JSON handlers for health, store discovery, and server info.
%%%
%%% Routes:
%%%   GET /v1/health                     gateway-level health
%%%   GET /v1/health/:store_id           per-store health
%%%   GET /v1/stores/:store_id/cluster   per-store cluster state (leader/quorum)
%%%   GET /v1/server-info/:store_id      version + integrity config
%%%   GET /v1/stores                     list all store instances
%%%   GET /v1/stores/:store_id           store instances for one store
-module(reckon_gateway_http_health).

-behaviour(cowboy_handler).

-export([init/2, live_stores/0, server_versions/0]).

%% @doc Gateway-global versions (gateway / reckon_db / API compat). These
%% are the gateway's own bundled versions and do not vary per store, so
%% the dashboard surfaces them in the header via the SSE status snapshot.
-spec server_versions() -> map().
server_versions() ->
    #{
        <<"gateway">>            => app_vsn(reckon_gateway),
        <<"reckon_db">>          => app_vsn(reckon_db),
        <<"api_compatibility">>  => <<"reckon.gateway.v1">>
    }.

%% @doc Enriched per-store snapshot for the live dashboard SSE stream.
%%
%% Folds each catalogue entry together with its cluster consistency
%% (leader / quorum / status) so the browser receives one live object per
%% store per tick, instead of fanning out an /cluster HTTP probe per store
%% on every refresh. Single-mode stores short-circuit the consistency RPC
%% (see handle_store_cluster/2).
-spec live_stores() -> [map()].
live_stores() ->
    [store_with_cluster(E) || E <- reckon_gateway_catalogue:list_entries()].

store_with_cluster(#{store_id := StoreId} = E) ->
    Base    = entry_to_json(E),
    Cluster = cluster_json(reckon_gateway_catalogue:store_mode(StoreId), StoreId),
    Base#{<<"cluster">>   => Cluster,
          <<"integrity">> => integrity_json(StoreId)}.

%% Per-store event-integrity advertisement (HMAC on/off + key id), folded
%% into the live snapshot so the dashboard can badge each store.
integrity_json(StoreId) ->
    Enabled = integrity_enabled(StoreId),
    {Algo, KeyId} = integrity_advert(Enabled),
    #{<<"enabled">> => Enabled,
      <<"algo">>    => Algo,
      <<"key_id">>  => KeyId}.

init(Req0, #{op := Op} = State) ->
    Req = handle(cowboy_req:method(Req0), Op, Req0),
    {ok, Req, State}.

handle(<<"OPTIONS">>, _Op, Req) ->
    reckon_gateway_http:cors_preflight(Req);

%% GET /v1/health  — gateway aggregate status
handle(<<"GET">>, gateway, Req) ->
    Snapshot = reckon_gateway_catalogue:status(),
    Clusters = maps:get(clusters, Snapshot, []),
    reckon_gateway_http:reply_json(200, #{
        <<"status">>          => gateway_status(Clusters),
        <<"node">>            => atom_to_binary(node(), utf8),
        <<"catalogue_size">>  => maps:get(catalogue_size, Snapshot, 0),
        <<"timestamp_ms">>    => erlang:system_time(millisecond)
    }, Req);

%% GET /v1/health/:store_id
handle(<<"GET">>, store, Req) ->
    with_store(Req, fun handle_store_health/2);

%% GET /v1/stores/:store_id/cluster
handle(<<"GET">>, cluster, Req) ->
    with_store(Req, fun handle_store_cluster/2);

%% GET /v1/server-info/:store_id
handle(<<"GET">>, server_info, Req) ->
    with_store(Req, fun handle_server_info/2);

%% GET /v1/admin/metrics — live throughput/latency snapshot
handle(<<"GET">>, metrics, Req) ->
    reckon_gateway_http:reply_json(200, reckon_gateway_metrics:snapshot_json(), Req);

%% GET /v1/stores
handle(<<"GET">>, list_stores, Req) ->
    Entries = reckon_gateway_catalogue:list_entries(),
    reckon_gateway_http:reply_json(200, #{
        <<"instances">> => [entry_to_json(E) || E <- Entries]
    }, Req);

%% GET /v1/stores/:store_id
handle(<<"GET">>, get_store, Req) ->
    with_store(Req, fun(StoreId, R) ->
        Entries  = reckon_gateway_catalogue:list_entries(),
        Filtered = [E || E <- Entries, maps:get(store_id, E) =:= StoreId],
        reckon_gateway_http:reply_json(200, #{
            <<"instances">> => [entry_to_json(E) || E <- Filtered]
        }, R)
    end);

handle(Method, Op, Req) ->
    reckon_gateway_http:reply_error(405,
        iolist_to_binary(io_lib:format("~s not allowed for ~p", [Method, Op])), Req).

%%====================================================================
%% Internal
%%====================================================================

with_store(Req, Fun) ->
    StoreIdBin = cowboy_req:binding(store_id, Req),
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_http:reply_error(400, <<"invalid_store_id">>, Req);
        {ok, StoreId} ->
            Fun(StoreId, Req)
    end.

gateway_status([])       -> <<"degraded">>;
gateway_status(Clusters) -> gateway_status_any(lists:any(fun cluster_up/1, Clusters)).

gateway_status_any(true)  -> <<"healthy">>;
gateway_status_any(false) -> <<"degraded">>.

cluster_up(#{status := up}) -> true;
cluster_up(_)               -> false.

handle_store_health(StoreId, R) ->
    {StatusAtom, Details} = health_result(reckon_gateway_dispatch:call(quick_health_check, [StoreId])),
    reckon_gateway_http:reply_json(200, #{
        <<"status">>  => atom_to_binary(StatusAtom, utf8),
        <<"details">> => Details
    }, R).

health_result({ok, _})         -> {healthy, #{}};
health_result({error, Reason}) -> {unhealthy, #{<<"reason">> => reason_bin(Reason)}}.

%% Per-store cluster state for the admin UI's leader/follower badges.
%%
%% Single-mode stores are short-circuited from the catalogue — there is
%% no Raft to inspect, and dispatching a consistency RPC to a
%% single-mode BEAM triggers reckon-gater's retry storm (see the
%% mirrored guard in reckon_gateway_health_service). Cluster-mode stores
%% dispatch `verify_cluster_consistency' and we lift the leader node +
%% quorum out of the reckon_db_cluster result into flat JSON so the UI
%% never has to parse Erlang terms.
handle_store_cluster(StoreId, R) ->
    Json = cluster_json(reckon_gateway_catalogue:store_mode(StoreId), StoreId),
    reckon_gateway_http:reply_json(200, Json, R).

cluster_json({ok, single}, _StoreId) ->
    #{<<"mode">>       => <<"single">>,
      <<"status">>     => <<"healthy">>,
      <<"leader">>     => null,
      <<"has_quorum">> => true};
cluster_json(_ModeResult, StoreId) ->
    consistency_json(reckon_gateway_dispatch:call(verify_cluster_consistency, [StoreId])).

consistency_json({ok, Info}) ->
    LeaderMap = maps:get(leader, Info, #{}),
    QuorumMap = maps:get(quorum, Info, #{}),
    #{<<"mode">>            => <<"cluster">>,
      <<"status">>          => atom_to_binary(maps:get(status, Info, degraded), utf8),
      <<"leader">>          => node_json(maps:get(leader, LeaderMap, undefined)),
      <<"has_quorum">>      => maps:get(has_quorum, QuorumMap, false),
      <<"total_nodes">>     => maps:get(total_nodes, QuorumMap, 0),
      <<"available_nodes">> => maps:get(available_nodes, QuorumMap, 0),
      <<"can_lose">>        => maps:get(can_lose, QuorumMap, 0)};
consistency_json({error, Reason}) ->
    #{<<"mode">>       => <<"cluster">>,
      <<"status">>     => <<"unavailable">>,
      <<"leader">>     => null,
      <<"has_quorum">> => false,
      <<"error">>      => reason_bin(Reason)}.

node_json(undefined)              -> null;
node_json(Node) when is_atom(Node) -> atom_to_binary(Node, utf8);
node_json(Other)                   -> iolist_to_binary(io_lib:format("~p", [Other])).

handle_server_info(StoreId, R) ->
    IntegrityEnabled = integrity_enabled(StoreId),
    {Algo, KeyId} = integrity_advert(IntegrityEnabled),
    reckon_gateway_http:reply_json(200, #{
        <<"reckon_db_version">>         => app_vsn(reckon_db),
        <<"reckon_gateway_version">>    => app_vsn(reckon_gateway),
        <<"api_compatibility_version">> => <<"reckon.gateway.v1">>,
        <<"integrity_algo">>            => Algo,
        <<"integrity_enabled">>         => IntegrityEnabled,
        <<"hmac_key_id">>               => KeyId
    }, R).

integrity_advert(true)  -> {<<"sha256-deterministic-etf-v1">>, 1};
integrity_advert(false) -> {<<>>, 0}.

entry_to_json(#{store_id := StoreId,
                node := Node,
                mode := Mode,
                data_dir := DataDir,
                timeout := Timeout,
                registered_at := RegisteredMs} = E) ->
    %% `nodes'/`replica_count' are folded in by the cluster connector
    %% (one per replica); default to the single `node' for legacy/local
    %% connectors that don't set them.
    Nodes = maps:get(nodes, E, [Node]),
    #{
        <<"store_id">>        => atom_to_binary(StoreId, utf8),
        <<"node">>            => atom_to_binary(Node, utf8),
        <<"nodes">>           => [atom_to_binary(N, utf8) || N <- Nodes],
        <<"replica_count">>   => maps:get(replica_count, E, length(Nodes)),
        <<"mode">>            => atom_to_binary(Mode, utf8),
        <<"data_dir">>        => unicode:characters_to_binary(DataDir),
        <<"timeout_ms">>      => Timeout,
        <<"registered_at_us">> => RegisteredMs * 1000
    }.

integrity_enabled(StoreId) ->
    try reckon_db_integrity_key:is_enabled(StoreId)
    catch _:_ -> false
    end.

app_vsn(App) ->
    case application:get_key(App, vsn) of
        {ok, Vsn} when is_list(Vsn) -> list_to_binary(Vsn);
        _                            -> <<"unknown">>
    end.

reason_bin(R) when is_atom(R)   -> atom_to_binary(R, utf8);
reason_bin(R) when is_binary(R) -> R;
reason_bin(R)                    -> iolist_to_binary(io_lib:format("~p", [R])).
