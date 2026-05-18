%% @doc gRPC StoresService implementation.
%%
%% Discovery-only: ListStores / GetStore / WatchStores. No
%% CreateStore / DeleteStore — store lifecycle is a deployment
%% concern (sys.config, hecate-gitops, podman units), and the
%% cluster view of "what stores exist" is just the union of who is
%% currently announcing themselves to the cluster-wide
%% reckon_db_store_registry.
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
    {ok, Entries} = reckon_db_store_registry:list_stores(),
    {ok, #{instances => [entry_to_proto(E) || E <- Entries]}, Md}.

get_store(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            {ok, Entries} = reckon_db_store_registry:list_stores(),
            Filtered = [E || E <- Entries, maps:get(store_id, E) =:= StoreId],
            {ok, #{instances => [entry_to_proto(E) || E <- Filtered]}, Md}
    end.

%%====================================================================
%% Server-streaming
%%====================================================================

%% Initial snapshot + live store-topology stream. Cleanup is implicit:
%% the registry monitors subscribers and prunes them on `DOWN', so
%% client disconnect (which kills this handler process) auto-removes
%% the subscription. No try/after, no explicit unsubscribe.
watch_stores(Stream0, _Md) ->
    {_, [Req], Stream} = grpc_stream:recv(Stream0),
    ok = reckon_db_store_registry:subscribe(self()),
    maybe_send_snapshot(maps:get(include_snapshot, Req, true), Stream),
    stream_events_loop(Stream).

maybe_send_snapshot(false, _Stream) ->
    ok;
maybe_send_snapshot(true, Stream) ->
    {ok, Entries} = reckon_db_store_registry:list_stores(),
    lists:foreach(fun(E) -> send_event(Stream, announced, E) end, Entries).

stream_events_loop(Stream) ->
    receive
        {store_event, EventType, Entry} ->
            send_event(Stream, EventType, Entry),
            stream_events_loop(Stream)
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
