%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.HealthService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_health_service_bhvr).

-callback check(reckon_health_pb:health_check_request(), grpc:metadata())
    -> {ok, reckon_health_pb:health_check_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback health(reckon_health_pb:health_request(), grpc:metadata())
    -> {ok, reckon_health_pb:health_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback verify_cluster_consistency(reckon_health_pb:cluster_check_request(), grpc:metadata())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback verify_membership_consensus(reckon_health_pb:cluster_check_request(), grpc:metadata())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback check_raft_log_consistency(reckon_health_pb:cluster_check_request(), grpc:metadata())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_memory_level(reckon_health_pb:memory_level_request(), grpc:metadata())
    -> {ok, reckon_health_pb:memory_level_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_memory_stats(reckon_health_pb:memory_stats_request(), grpc:metadata())
    -> {ok, reckon_health_pb:memory_stats_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_server_info(reckon_health_pb:get_server_info_request(), grpc:metadata())
    -> {ok, reckon_health_pb:server_info_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

