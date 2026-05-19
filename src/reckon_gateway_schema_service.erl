%% @doc gRPC SchemaService implementation.
%%
%% Error paths routed through reckon_gateway_error so the
%% underlying reason is logged server-side (grpc-erl drops
%% grpc-message on unary; see reckon_gateway_error docstring).
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
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(register_schema, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            Schema = json:decode(SchemaBytes),
            ok = reckon_gateway_dispatch:call(register_schema, [StoreId, EventType, Schema]),
            {ok, #{}, Md}
    end.

unregister_schema(#{store_id := StoreIdBin,
                    event_type := EventType}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(unregister_schema, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            ok = reckon_gateway_dispatch:call(unregister_schema, [StoreId, EventType]),
            {ok, #{}, Md}
    end.

get_schema(#{store_id := StoreIdBin,
             event_type := EventType}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(get_schema, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(get_schema, [StoreId, EventType]) of
                {ok, Schema} ->
                    {ok, #{event_type => EventType,
                           schema => json:encode(Schema),
                           version => maps:get(version, Schema, 1)}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(get_schema, <<"5">>, Reason)
            end
    end.

list_schemas(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(list_schemas, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(list_schemas, [StoreId]) of
                {ok, Schemas} ->
                    ProtoSchemas = [#{event_type => maps:get(event_type, S, <<>>),
                                      schema => json:encode(S),
                                      version => maps:get(version, S, 1)}
                                    || S <- Schemas],
                    {ok, #{schemas => ProtoSchemas}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(list_schemas, <<"13">>, Reason)
            end
    end.

get_schema_version(#{store_id := StoreIdBin,
                     event_type := EventType}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(get_schema_version, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(get_schema_version, [StoreId, EventType]) of
                {ok, Version} ->
                    {ok, #{version => Version}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(get_schema_version, <<"5">>, Reason)
            end
    end.

upcast_events(#{store_id := StoreIdBin,
                events := Events}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(upcast_events, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            %% Convert proto events to gater events, upcast, convert back
            GaterEvents = [proto_to_gater_event(E) || E <- Events],
            case reckon_gateway_dispatch:call(upcast_events, [StoreId, GaterEvents]) of
                {ok, Upcasted} ->
                    ProtoEvents = [reckon_gateway_convert:event_to_recorded(E) || E <- Upcasted],
                    {ok, #{events => ProtoEvents}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(upcast_events, <<"13">>, Reason)
            end
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
