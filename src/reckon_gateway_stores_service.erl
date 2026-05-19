%% @doc gRPC StoresService implementation.
%%
%% Catalogue-mode: ListStores / GetStore / WatchStores answer from
%% reckon_gateway_catalogue, the merged view across every connected
%% cluster. The local reckon-db registry is no longer consulted —
%% reckon-gateway 0.5.0 dropped reckon-db entirely.
%%
%% WatchStores subscribes to the catalogue's live store-event
%% stream. Initial snapshot (when requested) emits ANNOUNCED for
%% every current entry; subsequent ANNOUNCED/RETIRED events fire as
%% clusters publish updates. The catalogue monitors the handler
%% process and prunes the subscription on stream close.
-module(reckon_gateway_stores_service).

-behaviour(reckon_gateway_v_1_stores_service_bhvr).

-export([
    list_stores/2,
    get_store/2,
    watch_stores/2
]).

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

watch_stores(Stream0, _Md) ->
    {_, [Req], Stream} = grpc_stream:recv(Stream0),
    %% Subscribe FIRST so we don't miss events between snapshot
    %% and loop entry. The catalogue monitors our pid; if the gRPC
    %% library kills this process on client disconnect, the
    %% subscription cleans itself up.
    ok = reckon_gateway_catalogue:subscribe(self()),
    case maps:get(include_snapshot, Req, true) of
        true  -> emit_snapshot(Stream);
        false -> ok
    end,
    event_loop(Stream).

emit_snapshot(Stream) ->
    Entries = reckon_gateway_catalogue:list_entries(),
    lists:foreach(fun(E) -> send_event(Stream, announced, E) end, Entries).

event_loop(Stream) ->
    receive
        {store_event, EventType, Entry} ->
            send_event(Stream, EventType, Entry),
            event_loop(Stream);
        _ ->
            event_loop(Stream)
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
