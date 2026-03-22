%% @doc gRPC SchemaService implementation.
-module(reckon_gateway_schema_service).
-behaviour(reckon_gateway_v_1_schema_service_bhvr).

-export([
    register_schema/2,
    unregister_schema/2,
    get_schema/2,
    list_schemas/2,
    get_schema_version/2,
    upcast_events/2
]).

register_schema(Ctx, #{store_id := StoreIdBin,
                       event_type := EventType,
                       schema := SchemaBytes}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    Schema = json:decode(SchemaBytes),
    ok = esdb_gater_api:register_schema(StoreId, EventType, Schema),
    {ok, #{}, Ctx}.

unregister_schema(Ctx, #{store_id := StoreIdBin,
                         event_type := EventType}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    ok = esdb_gater_api:unregister_schema(StoreId, EventType),
    {ok, #{}, Ctx}.

get_schema(Ctx, #{store_id := StoreIdBin,
                  event_type := EventType}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_schema(StoreId, EventType) of
        {ok, Schema} ->
            {ok, #{event_type => EventType,
                   schema => json:encode(Schema),
                   version => maps:get(version, Schema, 1)}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

list_schemas(Ctx, #{store_id := StoreIdBin}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:list_schemas(StoreId) of
        {ok, Schemas} ->
            ProtoSchemas = [#{event_type => maps:get(event_type, S, <<>>),
                              schema => json:encode(S),
                              version => maps:get(version, S, 1)}
                            || S <- Schemas],
            {ok, #{schemas => ProtoSchemas}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

get_schema_version(Ctx, #{store_id := StoreIdBin,
                          event_type := EventType}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_schema_version(StoreId, EventType) of
        {ok, Version} ->
            {ok, #{version => Version}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

upcast_events(Ctx, #{store_id := StoreIdBin,
                     events := Events}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    %% Convert proto events to gater events, upcast, convert back
    GaterEvents = [proto_to_gater_event(E) || E <- Events],
    case esdb_gater_api:upcast_events(StoreId, GaterEvents) of
        {ok, Upcasted} ->
            ProtoEvents = [reckon_gateway_convert:event_to_recorded(E) || E <- Upcasted],
            {ok, #{events => ProtoEvents}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

%%====================================================================
%% Internal
%%====================================================================

proto_to_gater_event(#{event_type := Type, data := Data} = E) ->
    #{event_type => Type,
      data => json:decode(Data),
      version => maps:get(version, E, 0),
      metadata => case maps:get(metadata, E, <<>>) of
          <<>> -> #{};
          M -> json:decode(M)
      end}.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
