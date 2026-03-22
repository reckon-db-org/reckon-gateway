%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.StreamService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_stream_service_bhvr).

%% Unary RPC
-callback append_events(ctx:t(), reckon_streams_pb:append_events_request()) ->
    {ok, reckon_streams_pb:append_events_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback read_stream_forward(ctx:t(), reckon_streams_pb:read_stream_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback read_stream_backward(ctx:t(), reckon_streams_pb:read_stream_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% 
-callback stream_events_forward(reckon_streams_pb:read_stream_request(), grpcbox_stream:t()) ->
    ok | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_stream_version(ctx:t(), reckon_streams_pb:get_stream_version_request()) ->
    {ok, reckon_streams_pb:get_stream_version_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback list_streams(ctx:t(), reckon_streams_pb:list_streams_request()) ->
    {ok, reckon_streams_pb:list_streams_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback delete_stream(ctx:t(), reckon_streams_pb:delete_stream_request()) ->
    {ok, reckon_streams_pb:delete_stream_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback read_by_event_types(ctx:t(), reckon_streams_pb:read_by_event_types_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback read_by_tags(ctx:t(), reckon_streams_pb:read_by_tags_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback read_all_global(ctx:t(), reckon_streams_pb:read_all_global_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

