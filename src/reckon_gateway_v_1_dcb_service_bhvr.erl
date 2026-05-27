%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.DcbService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_dcb_service_bhvr).

-callback append_if_no_tag_matches(reckon_dcb_pb:append_if_no_tag_matches_request(), grpc:metadata())
    -> {ok, reckon_dcb_pb:append_if_no_tag_matches_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback read_dcb_context(reckon_dcb_pb:read_dcb_context_request(), grpc:metadata())
    -> {ok, reckon_dcb_pb:read_dcb_context_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

