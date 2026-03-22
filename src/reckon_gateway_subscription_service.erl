%% @doc gRPC SubscriptionService implementation.
-module(reckon_gateway_subscription_service).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-behaviour(reckon_gateway_v_1_subscription_service_bhvr).

-export([
    subscribe/2,
    ack_event/2,
    create_subscription/2,
    remove_subscription/2,
    list_subscriptions/2,
    get_subscription/2,
    get_subscription_lag/2
]).

%% Server-streaming: streams events to the subscriber.
%% grpcbox server-streaming callback: (Request, Stream) -> ok
subscribe(#{store_id := StoreIdBin,
            type := Type,
            selector := Selector,
            subscription_name := Name,
            start_from := StartFrom,
            pool_size := PoolSize}, Stream) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SubType = reckon_gateway_convert:subscription_type(Type),
    _PS = case PoolSize of 0 -> 1; _ -> PoolSize end,
    Self = self(),
    process_flag(trap_exit, true),
    ok = esdb_gater_api:save_subscription(
        StoreId, SubType, Selector, Name, StartFrom, Self),
    try
        stream_events_loop(Stream, StoreId, Name)
    after
        %% Always clean up the subscription when the stream ends
        esdb_gater_api:remove_subscription(StoreId, SubType, Selector, Name)
    end,
    ok.

ack_event(Ctx, #{store_id := StoreIdBin,
                 stream_id := StreamId,
                 subscription_name := _Name,
                 event_number := EventNumber}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    AckMap = #{event_number => EventNumber},
    ok = esdb_gater_api:ack_event(StoreId, StreamId, self(), AckMap),
    {ok, #{}, Ctx}.

create_subscription(Ctx, #{store_id := StoreIdBin,
                           type := Type,
                           selector := Selector,
                           subscription_name := Name,
                           start_from := StartFrom,
                           pool_size := PoolSize}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SubType = reckon_gateway_convert:subscription_type(Type),
    _PS = case PoolSize of 0 -> 1; _ -> PoolSize end,
    ok = esdb_gater_api:save_subscription(
        StoreId, SubType, Selector, Name, StartFrom, undefined),
    SubId = iolist_to_binary([atom_to_binary(StoreId), <<":">>, Name]),
    {ok, #{subscription_id => SubId}, Ctx}.

remove_subscription(Ctx, #{store_id := StoreIdBin,
                           type := Type,
                           selector := Selector,
                           subscription_name := Name}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SubType = reckon_gateway_convert:subscription_type(Type),
    ok = esdb_gater_api:remove_subscription(StoreId, SubType, Selector, Name),
    {ok, #{}, Ctx}.

list_subscriptions(Ctx, #{store_id := StoreIdBin}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_subscriptions(StoreId) of
        {ok, Subs} ->
            ProtoSubs = [reckon_gateway_convert:subscription_to_proto(S) || S <- Subs],
            {ok, #{subscriptions => ProtoSubs}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

get_subscription(Ctx, #{store_id := StoreIdBin,
                        subscription_name := Name}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_subscription(StoreId, Name) of
        {ok, Sub} ->
            {ok, reckon_gateway_convert:subscription_to_proto(Sub), Ctx};
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

get_subscription_lag(Ctx, #{store_id := StoreIdBin,
                            subscription_name := Name}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:subscription_lag(StoreId, Name) of
        {ok, LagInfo} ->
            {ok, #{lag => maps:get(lag, LagInfo, 0),
                   current_checkpoint => maps:get(checkpoint, LagInfo, 0),
                   latest_version => maps:get(latest_version, LagInfo, 0)}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

%%====================================================================
%% Internal
%%====================================================================

stream_events_loop(Stream, StoreId, Name) ->
    receive
        {events, Events} when is_list(Events) ->
            lists:foreach(
                fun(Event) ->
                    Recorded = reckon_gateway_convert:event_to_recorded(Event),
                    Msg = #{event => Recorded, checkpoint => Event#event.version},
                    grpcbox_stream:send(Msg, Stream)
                end,
                Events),
            stream_events_loop(Stream, StoreId, Name);
        stop ->
            ok;
        {'EXIT', _Pid, _Reason} ->
            %% Parent (h2_stream) died — client disconnected
            ok
    end.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
