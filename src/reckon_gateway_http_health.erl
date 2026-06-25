%%% @doc HTTP/JSON handlers for health, store discovery, and server info.
%%%
%%% Routes:
%%%   GET /v1/health                     gateway-level health
%%%   GET /v1/health/:store_id           per-store health
%%%   GET /v1/server-info/:store_id      version + integrity config
%%%   GET /v1/stores                     list all store instances
%%%   GET /v1/stores/:store_id           store instances for one store
-module(reckon_gateway_http_health).

-behaviour(cowboy_handler).

-export([init/2]).

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

%% GET /v1/server-info/:store_id
handle(<<"GET">>, server_info, Req) ->
    with_store(Req, fun handle_server_info/2);

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
                registered_at := RegisteredMs}) ->
    #{
        <<"store_id">>        => atom_to_binary(StoreId, utf8),
        <<"node">>            => atom_to_binary(Node, utf8),
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
