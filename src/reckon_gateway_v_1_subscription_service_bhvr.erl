%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.SubscriptionService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_subscription_service_bhvr).

%% 
-callback subscribe(reckon_subscriptions_pb:subscribe_request(), grpcbox_stream:t()) ->
    ok | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback ack_event(ctx:t(), reckon_subscriptions_pb:ack_event_request()) ->
    {ok, reckon_subscriptions_pb:ack_event_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback create_subscription(ctx:t(), reckon_subscriptions_pb:create_subscription_request()) ->
    {ok, reckon_subscriptions_pb:create_subscription_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback remove_subscription(ctx:t(), reckon_subscriptions_pb:remove_subscription_request()) ->
    {ok, reckon_subscriptions_pb:remove_subscription_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback list_subscriptions(ctx:t(), reckon_subscriptions_pb:list_subscriptions_request()) ->
    {ok, reckon_subscriptions_pb:list_subscriptions_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_subscription(ctx:t(), reckon_subscriptions_pb:get_subscription_request()) ->
    {ok, reckon_subscriptions_pb:subscription_info(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_subscription_lag(ctx:t(), reckon_subscriptions_pb:get_subscription_lag_request()) ->
    {ok, reckon_subscriptions_pb:get_subscription_lag_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

