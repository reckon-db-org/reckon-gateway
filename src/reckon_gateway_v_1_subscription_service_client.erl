%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.SubscriptionService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_subscription_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.SubscriptionService').
-define(PROTO_MODULE, 'reckon_subscriptions_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec subscribe(grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
subscribe(Options) ->
    subscribe(#{}, Options).

-spec subscribe(grpc:metadata(), grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
subscribe(Metadata, Options) ->
    grpc_client:open(?DEF(<<"/reckon.gateway.v1.SubscriptionService/Subscribe">>,
                          subscribe_request, subscription_event, <<"reckon.gateway.v1.SubscribeRequest">>),
                     Metadata, Options).

-spec ack_event(reckon_subscriptions_pb:ack_event_request())
    -> {ok, reckon_subscriptions_pb:ack_event_response(), grpc:metadata()}
     | {error, term()}.
ack_event(Req) ->
    ack_event(Req, #{}, #{}).

-spec ack_event(reckon_subscriptions_pb:ack_event_request(), grpc:options())
    -> {ok, reckon_subscriptions_pb:ack_event_response(), grpc:metadata()}
     | {error, term()}.
ack_event(Req, Options) ->
    ack_event(Req, #{}, Options).

-spec ack_event(reckon_subscriptions_pb:ack_event_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_subscriptions_pb:ack_event_response(), grpc:metadata()}
     | {error, term()}.
ack_event(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SubscriptionService/AckEvent">>,
                           ack_event_request, ack_event_response, <<"reckon.gateway.v1.AckEventRequest">>),
                      Req, Metadata, Options).

-spec create_subscription(reckon_subscriptions_pb:create_subscription_request())
    -> {ok, reckon_subscriptions_pb:create_subscription_response(), grpc:metadata()}
     | {error, term()}.
create_subscription(Req) ->
    create_subscription(Req, #{}, #{}).

-spec create_subscription(reckon_subscriptions_pb:create_subscription_request(), grpc:options())
    -> {ok, reckon_subscriptions_pb:create_subscription_response(), grpc:metadata()}
     | {error, term()}.
create_subscription(Req, Options) ->
    create_subscription(Req, #{}, Options).

-spec create_subscription(reckon_subscriptions_pb:create_subscription_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_subscriptions_pb:create_subscription_response(), grpc:metadata()}
     | {error, term()}.
create_subscription(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SubscriptionService/CreateSubscription">>,
                           create_subscription_request, create_subscription_response, <<"reckon.gateway.v1.CreateSubscriptionRequest">>),
                      Req, Metadata, Options).

-spec remove_subscription(reckon_subscriptions_pb:remove_subscription_request())
    -> {ok, reckon_subscriptions_pb:remove_subscription_response(), grpc:metadata()}
     | {error, term()}.
remove_subscription(Req) ->
    remove_subscription(Req, #{}, #{}).

-spec remove_subscription(reckon_subscriptions_pb:remove_subscription_request(), grpc:options())
    -> {ok, reckon_subscriptions_pb:remove_subscription_response(), grpc:metadata()}
     | {error, term()}.
remove_subscription(Req, Options) ->
    remove_subscription(Req, #{}, Options).

-spec remove_subscription(reckon_subscriptions_pb:remove_subscription_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_subscriptions_pb:remove_subscription_response(), grpc:metadata()}
     | {error, term()}.
remove_subscription(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SubscriptionService/RemoveSubscription">>,
                           remove_subscription_request, remove_subscription_response, <<"reckon.gateway.v1.RemoveSubscriptionRequest">>),
                      Req, Metadata, Options).

-spec list_subscriptions(reckon_subscriptions_pb:list_subscriptions_request())
    -> {ok, reckon_subscriptions_pb:list_subscriptions_response(), grpc:metadata()}
     | {error, term()}.
list_subscriptions(Req) ->
    list_subscriptions(Req, #{}, #{}).

-spec list_subscriptions(reckon_subscriptions_pb:list_subscriptions_request(), grpc:options())
    -> {ok, reckon_subscriptions_pb:list_subscriptions_response(), grpc:metadata()}
     | {error, term()}.
list_subscriptions(Req, Options) ->
    list_subscriptions(Req, #{}, Options).

-spec list_subscriptions(reckon_subscriptions_pb:list_subscriptions_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_subscriptions_pb:list_subscriptions_response(), grpc:metadata()}
     | {error, term()}.
list_subscriptions(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SubscriptionService/ListSubscriptions">>,
                           list_subscriptions_request, list_subscriptions_response, <<"reckon.gateway.v1.ListSubscriptionsRequest">>),
                      Req, Metadata, Options).

-spec get_subscription(reckon_subscriptions_pb:get_subscription_request())
    -> {ok, reckon_subscriptions_pb:subscription_info(), grpc:metadata()}
     | {error, term()}.
get_subscription(Req) ->
    get_subscription(Req, #{}, #{}).

-spec get_subscription(reckon_subscriptions_pb:get_subscription_request(), grpc:options())
    -> {ok, reckon_subscriptions_pb:subscription_info(), grpc:metadata()}
     | {error, term()}.
get_subscription(Req, Options) ->
    get_subscription(Req, #{}, Options).

-spec get_subscription(reckon_subscriptions_pb:get_subscription_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_subscriptions_pb:subscription_info(), grpc:metadata()}
     | {error, term()}.
get_subscription(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SubscriptionService/GetSubscription">>,
                           get_subscription_request, subscription_info, <<"reckon.gateway.v1.GetSubscriptionRequest">>),
                      Req, Metadata, Options).

-spec get_subscription_lag(reckon_subscriptions_pb:get_subscription_lag_request())
    -> {ok, reckon_subscriptions_pb:get_subscription_lag_response(), grpc:metadata()}
     | {error, term()}.
get_subscription_lag(Req) ->
    get_subscription_lag(Req, #{}, #{}).

-spec get_subscription_lag(reckon_subscriptions_pb:get_subscription_lag_request(), grpc:options())
    -> {ok, reckon_subscriptions_pb:get_subscription_lag_response(), grpc:metadata()}
     | {error, term()}.
get_subscription_lag(Req, Options) ->
    get_subscription_lag(Req, #{}, Options).

-spec get_subscription_lag(reckon_subscriptions_pb:get_subscription_lag_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_subscriptions_pb:get_subscription_lag_response(), grpc:metadata()}
     | {error, term()}.
get_subscription_lag(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SubscriptionService/GetSubscriptionLag">>,
                           get_subscription_lag_request, get_subscription_lag_response, <<"reckon.gateway.v1.GetSubscriptionLagRequest">>),
                      Req, Metadata, Options).

