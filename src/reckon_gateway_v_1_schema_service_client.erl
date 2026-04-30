%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.SchemaService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_schema_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.SchemaService').
-define(PROTO_MODULE, 'reckon_schema_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec register_schema(reckon_schema_pb:register_schema_request())
    -> {ok, reckon_schema_pb:register_schema_response(), grpc:metadata()}
     | {error, term()}.
register_schema(Req) ->
    register_schema(Req, #{}, #{}).

-spec register_schema(reckon_schema_pb:register_schema_request(), grpc:options())
    -> {ok, reckon_schema_pb:register_schema_response(), grpc:metadata()}
     | {error, term()}.
register_schema(Req, Options) ->
    register_schema(Req, #{}, Options).

-spec register_schema(reckon_schema_pb:register_schema_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_schema_pb:register_schema_response(), grpc:metadata()}
     | {error, term()}.
register_schema(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SchemaService/RegisterSchema">>,
                           register_schema_request, register_schema_response, <<"reckon.gateway.v1.RegisterSchemaRequest">>),
                      Req, Metadata, Options).

-spec unregister_schema(reckon_schema_pb:unregister_schema_request())
    -> {ok, reckon_schema_pb:unregister_schema_response(), grpc:metadata()}
     | {error, term()}.
unregister_schema(Req) ->
    unregister_schema(Req, #{}, #{}).

-spec unregister_schema(reckon_schema_pb:unregister_schema_request(), grpc:options())
    -> {ok, reckon_schema_pb:unregister_schema_response(), grpc:metadata()}
     | {error, term()}.
unregister_schema(Req, Options) ->
    unregister_schema(Req, #{}, Options).

-spec unregister_schema(reckon_schema_pb:unregister_schema_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_schema_pb:unregister_schema_response(), grpc:metadata()}
     | {error, term()}.
unregister_schema(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SchemaService/UnregisterSchema">>,
                           unregister_schema_request, unregister_schema_response, <<"reckon.gateway.v1.UnregisterSchemaRequest">>),
                      Req, Metadata, Options).

-spec get_schema(reckon_schema_pb:get_schema_request())
    -> {ok, reckon_schema_pb:get_schema_response(), grpc:metadata()}
     | {error, term()}.
get_schema(Req) ->
    get_schema(Req, #{}, #{}).

-spec get_schema(reckon_schema_pb:get_schema_request(), grpc:options())
    -> {ok, reckon_schema_pb:get_schema_response(), grpc:metadata()}
     | {error, term()}.
get_schema(Req, Options) ->
    get_schema(Req, #{}, Options).

-spec get_schema(reckon_schema_pb:get_schema_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_schema_pb:get_schema_response(), grpc:metadata()}
     | {error, term()}.
get_schema(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SchemaService/GetSchema">>,
                           get_schema_request, get_schema_response, <<"reckon.gateway.v1.GetSchemaRequest">>),
                      Req, Metadata, Options).

-spec list_schemas(reckon_schema_pb:list_schemas_request())
    -> {ok, reckon_schema_pb:list_schemas_response(), grpc:metadata()}
     | {error, term()}.
list_schemas(Req) ->
    list_schemas(Req, #{}, #{}).

-spec list_schemas(reckon_schema_pb:list_schemas_request(), grpc:options())
    -> {ok, reckon_schema_pb:list_schemas_response(), grpc:metadata()}
     | {error, term()}.
list_schemas(Req, Options) ->
    list_schemas(Req, #{}, Options).

-spec list_schemas(reckon_schema_pb:list_schemas_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_schema_pb:list_schemas_response(), grpc:metadata()}
     | {error, term()}.
list_schemas(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SchemaService/ListSchemas">>,
                           list_schemas_request, list_schemas_response, <<"reckon.gateway.v1.ListSchemasRequest">>),
                      Req, Metadata, Options).

-spec get_schema_version(reckon_schema_pb:get_schema_version_request())
    -> {ok, reckon_schema_pb:get_schema_version_response(), grpc:metadata()}
     | {error, term()}.
get_schema_version(Req) ->
    get_schema_version(Req, #{}, #{}).

-spec get_schema_version(reckon_schema_pb:get_schema_version_request(), grpc:options())
    -> {ok, reckon_schema_pb:get_schema_version_response(), grpc:metadata()}
     | {error, term()}.
get_schema_version(Req, Options) ->
    get_schema_version(Req, #{}, Options).

-spec get_schema_version(reckon_schema_pb:get_schema_version_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_schema_pb:get_schema_version_response(), grpc:metadata()}
     | {error, term()}.
get_schema_version(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SchemaService/GetSchemaVersion">>,
                           get_schema_version_request, get_schema_version_response, <<"reckon.gateway.v1.GetSchemaVersionRequest">>),
                      Req, Metadata, Options).

-spec upcast_events(reckon_schema_pb:upcast_events_request())
    -> {ok, reckon_schema_pb:upcast_events_response(), grpc:metadata()}
     | {error, term()}.
upcast_events(Req) ->
    upcast_events(Req, #{}, #{}).

-spec upcast_events(reckon_schema_pb:upcast_events_request(), grpc:options())
    -> {ok, reckon_schema_pb:upcast_events_response(), grpc:metadata()}
     | {error, term()}.
upcast_events(Req, Options) ->
    upcast_events(Req, #{}, Options).

-spec upcast_events(reckon_schema_pb:upcast_events_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_schema_pb:upcast_events_response(), grpc:metadata()}
     | {error, term()}.
upcast_events(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SchemaService/UpcastEvents">>,
                           upcast_events_request, upcast_events_response, <<"reckon.gateway.v1.UpcastEventsRequest">>),
                      Req, Metadata, Options).

