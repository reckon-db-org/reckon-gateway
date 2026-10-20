%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service grpc.health.v1.Health.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(grpc_health_v_1_health_bhvr).

-callback check(grpc_health_pb:health_check_request(), grpc:metadata())
    -> {ok, grpc_health_pb:health_check_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback watch(grpc_stream:stream(), grpc:metadata())
    -> {ok, grpc_stream:stream()}.

