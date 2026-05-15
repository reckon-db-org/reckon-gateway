%% @doc gRPC SchemaService implementation.
-module(reckon_gateway_schema_service).

-export([
    register_schema/2,
    unregister_schema/2,
    get_schema/2,
    list_schemas/2,
    get_schema_version/2,
    upcast_events/2
]).

register_schema(#{store_id := StoreIdBin,
                  event_type := EventType,
                  schema := SchemaBytes}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    Schema = json:decode(SchemaBytes),
    ok = reckon_gater_api:register_schema(StoreId, EventType, Schema),
    {ok, #{}, Md}.

unregister_schema(#{store_id := StoreIdBin,
                    event_type := EventType}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    ok = reckon_gater_api:unregister_schema(StoreId, EventType),
    {ok, #{}, Md}.

get_schema(#{store_id := StoreIdBin,
             event_type := EventType}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:get_schema(StoreId, EventType) of
        {ok, Schema} ->
            {ok, #{event_type => EventType,
                   schema => json:encode(Schema),
                   version => maps:get(version, Schema, 1)}, Md};
        {error, _Reason} ->
            {error, <<"5">>}
    end.

list_schemas(#{store_id := StoreIdBin}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:list_schemas(StoreId) of
        {ok, Schemas} ->
            ProtoSchemas = [#{event_type => maps:get(event_type, S, <<>>),
                              schema => json:encode(S),
                              version => maps:get(version, S, 1)}
                            || S <- Schemas],
            {ok, #{schemas => ProtoSchemas}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

get_schema_version(#{store_id := StoreIdBin,
                     event_type := EventType}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:get_schema_version(StoreId, EventType) of
        {ok, Version} ->
            {ok, #{version => Version}, Md};
        {error, _Reason} ->
            {error, <<"5">>}
    end.

upcast_events(#{store_id := StoreIdBin,
                events := Events}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    %% Convert proto events to gater events, upcast, convert back
    GaterEvents = [proto_to_gater_event(E) || E <- Events],
    case reckon_gater_api:upcast_events(StoreId, GaterEvents) of
        {ok, Upcasted} ->
            ProtoEvents = [reckon_gateway_convert:event_to_recorded(E) || E <- Upcasted],
            {ok, #{events => ProtoEvents}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
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
