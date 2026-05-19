%% @doc gRPC StoresService implementation.
%%
%% Catalogue-mode: ListStores / GetStore / WatchStores answer from
%% reckon_gateway_catalogue, the merged view across every connected
%% cluster. The local reckon-db registry is no longer consulted —
%% reckon-gateway 0.5.0 dropped reckon-db entirely.
%%
%% WatchStores in this release emits periodic snapshots only (no
%% live retired/announced events). Per
%% plans/DESIGN_RECKON_GATEWAY_CATALOGUE.md open question 2, the
%% phase-2 streaming aggregator is deferred until lazyreckon needs
%% it; for now polling is correct enough.
-module(reckon_gateway_stores_service).

-behaviour(reckon_gateway_v_1_stores_service_bhvr).

-export([
    list_stores/2,
    get_store/2,
    watch_stores/2
]).

-define(WATCH_SNAPSHOT_INTERVAL_MS, 5000).

%%====================================================================
%% Unary
%%====================================================================

list_stores(_Req, Md) ->
    Entries = reckon_gateway_catalogue:list_entries(),
    {ok, #{instances => [entry_to_proto(E) || E <- Entries]}, Md}.

get_store(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            Entries = reckon_gateway_catalogue:list_entries(),
            Filtered = [E || E <- Entries, maps:get(store_id, E) =:= StoreId],
            {ok, #{instances => [entry_to_proto(E) || E <- Filtered]}, Md}
    end.

%%====================================================================
%% Server-streaming
%%====================================================================

%% Phase-1 implementation: snapshot every WATCH_SNAPSHOT_INTERVAL_MS,
%% sending one ANNOUNCED event per entry. Crude but enough to drive
%% lazyreckon's stores mode while we decide on a phase-2 streaming
%% aggregator.
watch_stores(Stream0, _Md) ->
    {_, [Req], Stream} = grpc_stream:recv(Stream0),
    case maps:get(include_snapshot, Req, true) of
        true  -> emit_snapshot(Stream);
        false -> ok
    end,
    snapshot_loop(Stream).

emit_snapshot(Stream) ->
    Entries = reckon_gateway_catalogue:list_entries(),
    lists:foreach(fun(E) -> send_event(Stream, announced, E) end, Entries).

snapshot_loop(Stream) ->
    receive
        _ -> snapshot_loop(Stream)
    after ?WATCH_SNAPSHOT_INTERVAL_MS ->
        emit_snapshot(Stream),
        snapshot_loop(Stream)
    end.

send_event(Stream, EventType, Entry) ->
    grpc_stream:reply(Stream, #{
        type => proto_event_type(EventType),
        instance => entry_to_proto(Entry),
        event_at_us => erlang:system_time(microsecond)
    }).

%%====================================================================
%% Conversion
%%====================================================================

proto_event_type(announced) -> 'STORE_EVENT_TYPE_ANNOUNCED';
proto_event_type(retired)   -> 'STORE_EVENT_TYPE_RETIRED'.

%% Convert a store-registry entry map (from reckon_db_store_registry)
%% into the proto StoreInstance shape.
entry_to_proto(#{store_id := StoreId,
                 node := Node,
                 mode := Mode,
                 data_dir := DataDir,
                 timeout := Timeout,
                 registered_at := RegisteredMs}) ->
    #{
        store_id => atom_to_binary(StoreId, utf8),
        node => atom_to_binary(Node, utf8),
        mode => proto_mode(Mode),
        data_dir => unicode:characters_to_binary(DataDir),
        timeout_ms => Timeout,
        registered_at_us => RegisteredMs * 1000
    }.

proto_mode(single)  -> 'STORE_MODE_SINGLE';
proto_mode(cluster) -> 'STORE_MODE_CLUSTER'.
