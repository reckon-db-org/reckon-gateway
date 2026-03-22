%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.SchemaService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_schema_service_bhvr).

%% Unary RPC
-callback register_schema(ctx:t(), reckon_schema_pb:register_schema_request()) ->
    {ok, reckon_schema_pb:register_schema_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback unregister_schema(ctx:t(), reckon_schema_pb:unregister_schema_request()) ->
    {ok, reckon_schema_pb:unregister_schema_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_schema(ctx:t(), reckon_schema_pb:get_schema_request()) ->
    {ok, reckon_schema_pb:get_schema_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback list_schemas(ctx:t(), reckon_schema_pb:list_schemas_request()) ->
    {ok, reckon_schema_pb:list_schemas_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_schema_version(ctx:t(), reckon_schema_pb:get_schema_version_request()) ->
    {ok, reckon_schema_pb:get_schema_version_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback upcast_events(ctx:t(), reckon_schema_pb:upcast_events_request()) ->
    {ok, reckon_schema_pb:upcast_events_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

