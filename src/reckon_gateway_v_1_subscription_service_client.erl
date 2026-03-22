%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.SubscriptionService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_subscription_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpcbox/include/grpcbox.hrl").

-define(is_ctx(Ctx), is_tuple(Ctx) andalso element(1, Ctx) =:= ctx).

-define(SERVICE, 'reckon.gateway.v1.SubscriptionService').
-define(PROTO_MODULE, 'reckon_subscriptions_pb').
-define(MARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Input, Output, MessageType), #grpcbox_def{service=?SERVICE,
                                                      message_type=MessageType,
                                                      marshal_fun=?MARSHAL_FUN(Input),
                                                      unmarshal_fun=?UNMARSHAL_FUN(Output)}).

%% @doc 
-spec subscribe(reckon_subscriptions_pb:subscribe_request()) ->
    {ok, grpcbox_client:stream()} | grpcbox_stream:grpc_error_response() | {error, any()}.
subscribe(Input) ->
    subscribe(ctx:new(), Input, #{}).

-spec subscribe(ctx:t() | reckon_subscriptions_pb:subscribe_request(), reckon_subscriptions_pb:subscribe_request() | grpcbox_client:options()) ->
    {ok, grpcbox_client:stream()} | grpcbox_stream:grpc_error_response() | {error, any()}.
subscribe(Ctx, Input) when ?is_ctx(Ctx) ->
    subscribe(Ctx, Input, #{});
subscribe(Input, Options) ->
    subscribe(ctx:new(), Input, Options).

-spec subscribe(ctx:t(), reckon_subscriptions_pb:subscribe_request(), grpcbox_client:options()) ->
    {ok, grpcbox_client:stream()} | grpcbox_stream:grpc_error_response() | {error, any()}.
subscribe(Ctx, Input, Options) ->
    grpcbox_client:stream(Ctx, <<"/reckon.gateway.v1.SubscriptionService/Subscribe">>, Input, ?DEF(subscribe_request, subscription_event, <<"reckon.gateway.v1.SubscribeRequest">>), Options).

%% @doc Unary RPC
-spec ack_event(reckon_subscriptions_pb:ack_event_request()) ->
    {ok, reckon_subscriptions_pb:ack_event_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
ack_event(Input) ->
    ack_event(ctx:new(), Input, #{}).

-spec ack_event(ctx:t() | reckon_subscriptions_pb:ack_event_request(), reckon_subscriptions_pb:ack_event_request() | grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:ack_event_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
ack_event(Ctx, Input) when ?is_ctx(Ctx) ->
    ack_event(Ctx, Input, #{});
ack_event(Input, Options) ->
    ack_event(ctx:new(), Input, Options).

-spec ack_event(ctx:t(), reckon_subscriptions_pb:ack_event_request(), grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:ack_event_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
ack_event(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SubscriptionService/AckEvent">>, Input, ?DEF(ack_event_request, ack_event_response, <<"reckon.gateway.v1.AckEventRequest">>), Options).

%% @doc Unary RPC
-spec create_subscription(reckon_subscriptions_pb:create_subscription_request()) ->
    {ok, reckon_subscriptions_pb:create_subscription_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
create_subscription(Input) ->
    create_subscription(ctx:new(), Input, #{}).

-spec create_subscription(ctx:t() | reckon_subscriptions_pb:create_subscription_request(), reckon_subscriptions_pb:create_subscription_request() | grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:create_subscription_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
create_subscription(Ctx, Input) when ?is_ctx(Ctx) ->
    create_subscription(Ctx, Input, #{});
create_subscription(Input, Options) ->
    create_subscription(ctx:new(), Input, Options).

-spec create_subscription(ctx:t(), reckon_subscriptions_pb:create_subscription_request(), grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:create_subscription_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
create_subscription(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SubscriptionService/CreateSubscription">>, Input, ?DEF(create_subscription_request, create_subscription_response, <<"reckon.gateway.v1.CreateSubscriptionRequest">>), Options).

%% @doc Unary RPC
-spec remove_subscription(reckon_subscriptions_pb:remove_subscription_request()) ->
    {ok, reckon_subscriptions_pb:remove_subscription_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
remove_subscription(Input) ->
    remove_subscription(ctx:new(), Input, #{}).

-spec remove_subscription(ctx:t() | reckon_subscriptions_pb:remove_subscription_request(), reckon_subscriptions_pb:remove_subscription_request() | grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:remove_subscription_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
remove_subscription(Ctx, Input) when ?is_ctx(Ctx) ->
    remove_subscription(Ctx, Input, #{});
remove_subscription(Input, Options) ->
    remove_subscription(ctx:new(), Input, Options).

-spec remove_subscription(ctx:t(), reckon_subscriptions_pb:remove_subscription_request(), grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:remove_subscription_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
remove_subscription(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SubscriptionService/RemoveSubscription">>, Input, ?DEF(remove_subscription_request, remove_subscription_response, <<"reckon.gateway.v1.RemoveSubscriptionRequest">>), Options).

%% @doc Unary RPC
-spec list_subscriptions(reckon_subscriptions_pb:list_subscriptions_request()) ->
    {ok, reckon_subscriptions_pb:list_subscriptions_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_subscriptions(Input) ->
    list_subscriptions(ctx:new(), Input, #{}).

-spec list_subscriptions(ctx:t() | reckon_subscriptions_pb:list_subscriptions_request(), reckon_subscriptions_pb:list_subscriptions_request() | grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:list_subscriptions_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_subscriptions(Ctx, Input) when ?is_ctx(Ctx) ->
    list_subscriptions(Ctx, Input, #{});
list_subscriptions(Input, Options) ->
    list_subscriptions(ctx:new(), Input, Options).

-spec list_subscriptions(ctx:t(), reckon_subscriptions_pb:list_subscriptions_request(), grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:list_subscriptions_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_subscriptions(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SubscriptionService/ListSubscriptions">>, Input, ?DEF(list_subscriptions_request, list_subscriptions_response, <<"reckon.gateway.v1.ListSubscriptionsRequest">>), Options).

%% @doc Unary RPC
-spec get_subscription(reckon_subscriptions_pb:get_subscription_request()) ->
    {ok, reckon_subscriptions_pb:subscription_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_subscription(Input) ->
    get_subscription(ctx:new(), Input, #{}).

-spec get_subscription(ctx:t() | reckon_subscriptions_pb:get_subscription_request(), reckon_subscriptions_pb:get_subscription_request() | grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:subscription_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_subscription(Ctx, Input) when ?is_ctx(Ctx) ->
    get_subscription(Ctx, Input, #{});
get_subscription(Input, Options) ->
    get_subscription(ctx:new(), Input, Options).

-spec get_subscription(ctx:t(), reckon_subscriptions_pb:get_subscription_request(), grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:subscription_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_subscription(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SubscriptionService/GetSubscription">>, Input, ?DEF(get_subscription_request, subscription_info, <<"reckon.gateway.v1.GetSubscriptionRequest">>), Options).

%% @doc Unary RPC
-spec get_subscription_lag(reckon_subscriptions_pb:get_subscription_lag_request()) ->
    {ok, reckon_subscriptions_pb:get_subscription_lag_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_subscription_lag(Input) ->
    get_subscription_lag(ctx:new(), Input, #{}).

-spec get_subscription_lag(ctx:t() | reckon_subscriptions_pb:get_subscription_lag_request(), reckon_subscriptions_pb:get_subscription_lag_request() | grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:get_subscription_lag_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_subscription_lag(Ctx, Input) when ?is_ctx(Ctx) ->
    get_subscription_lag(Ctx, Input, #{});
get_subscription_lag(Input, Options) ->
    get_subscription_lag(ctx:new(), Input, Options).

-spec get_subscription_lag(ctx:t(), reckon_subscriptions_pb:get_subscription_lag_request(), grpcbox_client:options()) ->
    {ok, reckon_subscriptions_pb:get_subscription_lag_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_subscription_lag(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SubscriptionService/GetSubscriptionLag">>, Input, ?DEF(get_subscription_lag_request, get_subscription_lag_response, <<"reckon.gateway.v1.GetSubscriptionLagRequest">>), Options).

