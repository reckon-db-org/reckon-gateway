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
    with_store_id(StoreIdBin, get_schema,
        fun(StoreId) ->
            get_schema_reply(reckon_gateway_dispatch:call(get_schema, [StoreId, EventType]),
                             EventType, Md)
        end).

get_schema_reply({ok, Schema}, EventType, Md) ->
    {ok, #{event_type => EventType,
           schema => json:encode(Schema),
           version => maps:get(version, Schema, 1)}, Md};
get_schema_reply({error, Reason}, _EventType, _Md) ->
    reckon_gateway_error:wrap(get_schema, <<"5">>, Reason).

list_schemas(#{store_id := StoreIdBin}, Md) ->
    with_store_id(StoreIdBin, list_schemas,
        fun(StoreId) -> list_schemas_reply(reckon_gateway_dispatch:call(list_schemas, [StoreId]), Md) end).

list_schemas_reply({ok, Schemas}, Md) ->
    ProtoSchemas = [#{event_type => maps:get(event_type, S, <<>>),
                      schema => json:encode(S),
                      version => maps:get(version, S, 1)} || S <- Schemas],
    {ok, #{schemas => ProtoSchemas}, Md};
list_schemas_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(list_schemas, <<"13">>, Reason).

get_schema_version(#{store_id := StoreIdBin,
                     event_type := EventType}, Md) ->
    with_store_id(StoreIdBin, get_schema_version,
        fun(StoreId) ->
            schema_version_reply(
                reckon_gateway_dispatch:call(get_schema_version, [StoreId, EventType]), Md)
        end).

schema_version_reply({ok, Version}, Md) ->
    {ok, #{version => Version}, Md};
schema_version_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(get_schema_version, <<"5">>, Reason).

upcast_events(#{store_id := StoreIdBin,
                events := Events}, Md) ->
    with_store_id(StoreIdBin, upcast_events,
        fun(StoreId) -> upcast_reply(StoreId, Events, Md) end).

%% @private Convert proto events to gater events, upcast, convert back.
upcast_reply(StoreId, Events, Md) ->
    GaterEvents = [proto_to_gater_event(E) || E <- Events],
    upcast_result(reckon_gateway_dispatch:call(upcast_events, [StoreId, GaterEvents]), Md).

upcast_result({ok, Upcasted}, Md) ->
    {ok, #{events => [reckon_gateway_convert:event_to_recorded(E) || E <- Upcasted]}, Md};
upcast_result({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(upcast_events, <<"13">>, Reason).

%%====================================================================
%% Internal
%%====================================================================

%% @private Resolve a store-id binary, wrapping the canonical
%% invalid_store_id gRPC error, then run Fun with the parsed id.
with_store_id(StoreIdBin, ErrFn, Fun) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(ErrFn, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            Fun(StoreId)
    end.

proto_to_gater_event(#{event_type := Type, data := Data} = E) ->
    #{event_type => Type,
      data => json:decode(Data),
      version => maps:get(version, E, 0),
      metadata => case maps:get(metadata, E, <<>>) of
          <<>> -> #{};
          M -> json:decode(M)
      end}.
