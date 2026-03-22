%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.HealthService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_health_service_bhvr).

%% Unary RPC
-callback check(ctx:t(), reckon_health_pb:health_check_request()) ->
    {ok, reckon_health_pb:health_check_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback health(ctx:t(), reckon_health_pb:health_request()) ->
    {ok, reckon_health_pb:health_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback verify_cluster_consistency(ctx:t(), reckon_health_pb:cluster_check_request()) ->
    {ok, reckon_health_pb:cluster_check_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback verify_membership_consensus(ctx:t(), reckon_health_pb:cluster_check_request()) ->
    {ok, reckon_health_pb:cluster_check_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback check_raft_log_consistency(ctx:t(), reckon_health_pb:cluster_check_request()) ->
    {ok, reckon_health_pb:cluster_check_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_memory_level(ctx:t(), reckon_health_pb:memory_level_request()) ->
    {ok, reckon_health_pb:memory_level_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_memory_stats(ctx:t(), reckon_health_pb:memory_stats_request()) ->
    {ok, reckon_health_pb:memory_stats_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

