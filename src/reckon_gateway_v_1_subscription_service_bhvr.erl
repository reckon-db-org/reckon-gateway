%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.SubscriptionService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_subscription_service_bhvr).

-callback subscribe(grpc_stream:stream(), grpc:metadata())
    -> {ok, grpc_stream:stream()}.

-callback ack_event(reckon_subscriptions_pb:ack_event_request(), grpc:metadata())
    -> {ok, reckon_subscriptions_pb:ack_event_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback create_subscription(reckon_subscriptions_pb:create_subscription_request(), grpc:metadata())
    -> {ok, reckon_subscriptions_pb:create_subscription_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback remove_subscription(reckon_subscriptions_pb:remove_subscription_request(), grpc:metadata())
    -> {ok, reckon_subscriptions_pb:remove_subscription_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback list_subscriptions(reckon_subscriptions_pb:list_subscriptions_request(), grpc:metadata())
    -> {ok, reckon_subscriptions_pb:list_subscriptions_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_subscription(reckon_subscriptions_pb:get_subscription_request(), grpc:metadata())
    -> {ok, reckon_subscriptions_pb:subscription_info(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_subscription_lag(reckon_subscriptions_pb:get_subscription_lag_request(), grpc:metadata())
    -> {ok, reckon_subscriptions_pb:get_subscription_lag_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

