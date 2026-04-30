%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.CausationService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_causation_service_bhvr).

-callback get_effects(reckon_causation_pb:causation_request(), grpc:metadata())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_cause(reckon_causation_pb:causation_request(), grpc:metadata())
    -> {ok, reckon_causation_pb:single_event_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_causation_chain(reckon_causation_pb:causation_request(), grpc:metadata())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_correlated(reckon_causation_pb:correlation_request(), grpc:metadata())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback build_causation_graph(reckon_causation_pb:causation_request(), grpc:metadata())
    -> {ok, reckon_causation_pb:causation_graph_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

