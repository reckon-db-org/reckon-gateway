%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.CausationService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_causation_service_bhvr).

%% Unary RPC
-callback get_effects(ctx:t(), reckon_causation_pb:causation_request()) ->
    {ok, reckon_causation_pb:causation_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_cause(ctx:t(), reckon_causation_pb:causation_request()) ->
    {ok, reckon_causation_pb:single_event_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_causation_chain(ctx:t(), reckon_causation_pb:causation_request()) ->
    {ok, reckon_causation_pb:causation_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_correlated(ctx:t(), reckon_causation_pb:correlation_request()) ->
    {ok, reckon_causation_pb:causation_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback build_causation_graph(ctx:t(), reckon_causation_pb:causation_request()) ->
    {ok, reckon_causation_pb:causation_graph_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

