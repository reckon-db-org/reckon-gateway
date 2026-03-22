%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.TemporalService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_temporal_service_bhvr).

%% Unary RPC
-callback read_until(ctx:t(), reckon_temporal_pb:read_until_request()) ->
    {ok, reckon_temporal_pb:read_until_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback read_range(ctx:t(), reckon_temporal_pb:read_range_request()) ->
    {ok, reckon_temporal_pb:read_range_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback version_at(ctx:t(), reckon_temporal_pb:version_at_request()) ->
    {ok, reckon_temporal_pb:version_at_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

