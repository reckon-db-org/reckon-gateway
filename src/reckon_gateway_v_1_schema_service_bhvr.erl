%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.SchemaService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_schema_service_bhvr).

-callback register_schema(reckon_schema_pb:register_schema_request(), grpc:metadata())
    -> {ok, reckon_schema_pb:register_schema_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback unregister_schema(reckon_schema_pb:unregister_schema_request(), grpc:metadata())
    -> {ok, reckon_schema_pb:unregister_schema_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_schema(reckon_schema_pb:get_schema_request(), grpc:metadata())
    -> {ok, reckon_schema_pb:get_schema_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback list_schemas(reckon_schema_pb:list_schemas_request(), grpc:metadata())
    -> {ok, reckon_schema_pb:list_schemas_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_schema_version(reckon_schema_pb:get_schema_version_request(), grpc:metadata())
    -> {ok, reckon_schema_pb:get_schema_version_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback upcast_events(reckon_schema_pb:upcast_events_request(), grpc:metadata())
    -> {ok, reckon_schema_pb:upcast_events_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

