%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.SchemaService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_schema_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpcbox/include/grpcbox.hrl").

-define(is_ctx(Ctx), is_tuple(Ctx) andalso element(1, Ctx) =:= ctx).

-define(SERVICE, 'reckon.gateway.v1.SchemaService').
-define(PROTO_MODULE, 'reckon_schema_pb').
-define(MARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Input, Output, MessageType), #grpcbox_def{service=?SERVICE,
                                                      message_type=MessageType,
                                                      marshal_fun=?MARSHAL_FUN(Input),
                                                      unmarshal_fun=?UNMARSHAL_FUN(Output)}).

%% @doc Unary RPC
-spec register_schema(reckon_schema_pb:register_schema_request()) ->
    {ok, reckon_schema_pb:register_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
register_schema(Input) ->
    register_schema(ctx:new(), Input, #{}).

-spec register_schema(ctx:t() | reckon_schema_pb:register_schema_request(), reckon_schema_pb:register_schema_request() | grpcbox_client:options()) ->
    {ok, reckon_schema_pb:register_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
register_schema(Ctx, Input) when ?is_ctx(Ctx) ->
    register_schema(Ctx, Input, #{});
register_schema(Input, Options) ->
    register_schema(ctx:new(), Input, Options).

-spec register_schema(ctx:t(), reckon_schema_pb:register_schema_request(), grpcbox_client:options()) ->
    {ok, reckon_schema_pb:register_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
register_schema(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SchemaService/RegisterSchema">>, Input, ?DEF(register_schema_request, register_schema_response, <<"reckon.gateway.v1.RegisterSchemaRequest">>), Options).

%% @doc Unary RPC
-spec unregister_schema(reckon_schema_pb:unregister_schema_request()) ->
    {ok, reckon_schema_pb:unregister_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
unregister_schema(Input) ->
    unregister_schema(ctx:new(), Input, #{}).

-spec unregister_schema(ctx:t() | reckon_schema_pb:unregister_schema_request(), reckon_schema_pb:unregister_schema_request() | grpcbox_client:options()) ->
    {ok, reckon_schema_pb:unregister_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
unregister_schema(Ctx, Input) when ?is_ctx(Ctx) ->
    unregister_schema(Ctx, Input, #{});
unregister_schema(Input, Options) ->
    unregister_schema(ctx:new(), Input, Options).

-spec unregister_schema(ctx:t(), reckon_schema_pb:unregister_schema_request(), grpcbox_client:options()) ->
    {ok, reckon_schema_pb:unregister_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
unregister_schema(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SchemaService/UnregisterSchema">>, Input, ?DEF(unregister_schema_request, unregister_schema_response, <<"reckon.gateway.v1.UnregisterSchemaRequest">>), Options).

%% @doc Unary RPC
-spec get_schema(reckon_schema_pb:get_schema_request()) ->
    {ok, reckon_schema_pb:get_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_schema(Input) ->
    get_schema(ctx:new(), Input, #{}).

-spec get_schema(ctx:t() | reckon_schema_pb:get_schema_request(), reckon_schema_pb:get_schema_request() | grpcbox_client:options()) ->
    {ok, reckon_schema_pb:get_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_schema(Ctx, Input) when ?is_ctx(Ctx) ->
    get_schema(Ctx, Input, #{});
get_schema(Input, Options) ->
    get_schema(ctx:new(), Input, Options).

-spec get_schema(ctx:t(), reckon_schema_pb:get_schema_request(), grpcbox_client:options()) ->
    {ok, reckon_schema_pb:get_schema_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_schema(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SchemaService/GetSchema">>, Input, ?DEF(get_schema_request, get_schema_response, <<"reckon.gateway.v1.GetSchemaRequest">>), Options).

%% @doc Unary RPC
-spec list_schemas(reckon_schema_pb:list_schemas_request()) ->
    {ok, reckon_schema_pb:list_schemas_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_schemas(Input) ->
    list_schemas(ctx:new(), Input, #{}).

-spec list_schemas(ctx:t() | reckon_schema_pb:list_schemas_request(), reckon_schema_pb:list_schemas_request() | grpcbox_client:options()) ->
    {ok, reckon_schema_pb:list_schemas_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_schemas(Ctx, Input) when ?is_ctx(Ctx) ->
    list_schemas(Ctx, Input, #{});
list_schemas(Input, Options) ->
    list_schemas(ctx:new(), Input, Options).

-spec list_schemas(ctx:t(), reckon_schema_pb:list_schemas_request(), grpcbox_client:options()) ->
    {ok, reckon_schema_pb:list_schemas_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_schemas(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SchemaService/ListSchemas">>, Input, ?DEF(list_schemas_request, list_schemas_response, <<"reckon.gateway.v1.ListSchemasRequest">>), Options).

%% @doc Unary RPC
-spec get_schema_version(reckon_schema_pb:get_schema_version_request()) ->
    {ok, reckon_schema_pb:get_schema_version_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_schema_version(Input) ->
    get_schema_version(ctx:new(), Input, #{}).

-spec get_schema_version(ctx:t() | reckon_schema_pb:get_schema_version_request(), reckon_schema_pb:get_schema_version_request() | grpcbox_client:options()) ->
    {ok, reckon_schema_pb:get_schema_version_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_schema_version(Ctx, Input) when ?is_ctx(Ctx) ->
    get_schema_version(Ctx, Input, #{});
get_schema_version(Input, Options) ->
    get_schema_version(ctx:new(), Input, Options).

-spec get_schema_version(ctx:t(), reckon_schema_pb:get_schema_version_request(), grpcbox_client:options()) ->
    {ok, reckon_schema_pb:get_schema_version_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_schema_version(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SchemaService/GetSchemaVersion">>, Input, ?DEF(get_schema_version_request, get_schema_version_response, <<"reckon.gateway.v1.GetSchemaVersionRequest">>), Options).

%% @doc Unary RPC
-spec upcast_events(reckon_schema_pb:upcast_events_request()) ->
    {ok, reckon_schema_pb:upcast_events_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
upcast_events(Input) ->
    upcast_events(ctx:new(), Input, #{}).

-spec upcast_events(ctx:t() | reckon_schema_pb:upcast_events_request(), reckon_schema_pb:upcast_events_request() | grpcbox_client:options()) ->
    {ok, reckon_schema_pb:upcast_events_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
upcast_events(Ctx, Input) when ?is_ctx(Ctx) ->
    upcast_events(Ctx, Input, #{});
upcast_events(Input, Options) ->
    upcast_events(ctx:new(), Input, Options).

-spec upcast_events(ctx:t(), reckon_schema_pb:upcast_events_request(), grpcbox_client:options()) ->
    {ok, reckon_schema_pb:upcast_events_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
upcast_events(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SchemaService/UpcastEvents">>, Input, ?DEF(upcast_events_request, upcast_events_response, <<"reckon.gateway.v1.UpcastEventsRequest">>), Options).

