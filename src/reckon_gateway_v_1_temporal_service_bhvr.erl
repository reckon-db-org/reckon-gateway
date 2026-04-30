%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.TemporalService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_temporal_service_bhvr).

-callback read_until(reckon_temporal_pb:read_until_request(), grpc:metadata())
    -> {ok, reckon_temporal_pb:read_until_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback read_range(reckon_temporal_pb:read_range_request(), grpc:metadata())
    -> {ok, reckon_temporal_pb:read_range_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback version_at(reckon_temporal_pb:version_at_request(), grpc:metadata())
    -> {ok, reckon_temporal_pb:version_at_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

