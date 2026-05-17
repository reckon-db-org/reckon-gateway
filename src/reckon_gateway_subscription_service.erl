%% @doc gRPC SubscriptionService implementation.
-module(reckon_gateway_subscription_service).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").

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
%% grpc-erl server-streaming callback: (Stream, Md) -> {ok, Stream}
subscribe(Stream, _Md) ->
    {_, [#{store_id := StoreIdBin,
           type := Type,
           selector := Selector,
           subscription_name := Name,
           start_from := StartFrom,
           pool_size := PoolSize}], Stream1} = grpc_stream:recv(Stream),
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SubType = reckon_gateway_convert:subscription_type(Type),
    _PS = case PoolSize of 0 -> 1; _ -> PoolSize end,
    Self = self(),
    process_flag(trap_exit, true),
    ok = reckon_gater_api:save_subscription(
        StoreId, SubType, Selector, Name, StartFrom, Self),
    try
        stream_events_loop(Stream1, StoreId, Name)
    after
        %% Always clean up the subscription when the stream ends
        reckon_gater_api:remove_subscription(StoreId, SubType, Selector, Name)
    end.

ack_event(#{store_id := StoreIdBin,
            stream_id := StreamId,
            subscription_name := _Name,
            event_number := EventNumber}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    AckMap = #{event_number => EventNumber},
    ok = reckon_gater_api:ack_event(StoreId, StreamId, self(), AckMap),
    {ok, #{}, Md}.

create_subscription(#{store_id := StoreIdBin,
                      type := Type,
                      selector := Selector,
                      subscription_name := Name,
                      start_from := StartFrom,
                      pool_size := PoolSize}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SubType = reckon_gateway_convert:subscription_type(Type),
    _PS = case PoolSize of 0 -> 1; _ -> PoolSize end,
    ok = reckon_gater_api:save_subscription(
        StoreId, SubType, Selector, Name, StartFrom, undefined),
    SubId = iolist_to_binary([atom_to_binary(StoreId), <<":">>, Name]),
    {ok, #{subscription_id => SubId}, Md}.

remove_subscription(#{store_id := StoreIdBin,
                      type := Type,
                      selector := Selector,
                      subscription_name := Name}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SubType = reckon_gateway_convert:subscription_type(Type),
    ok = reckon_gater_api:remove_subscription(StoreId, SubType, Selector, Name),
    {ok, #{}, Md}.

list_subscriptions(#{store_id := StoreIdBin}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:get_subscriptions(StoreId) of
        {ok, Subs} ->
            ProtoSubs = [reckon_gateway_convert:subscription_to_proto(S) || S <- Subs],
            {ok, #{subscriptions => ProtoSubs}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

get_subscription(#{store_id := StoreIdBin,
                   subscription_name := Name}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:get_subscription(StoreId, Name) of
        {ok, Sub} ->
            {ok, reckon_gateway_convert:subscription_to_proto(Sub), Md};
        {error, _Reason} ->
            {error, <<"5">>}
    end.

get_subscription_lag(#{store_id := StoreIdBin,
                       subscription_name := Name}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:subscription_lag(StoreId, Name) of
        {ok, LagInfo} ->
            %% reckon_db_store_inspector:subscription_lag/2 returns
            %% #{checkpoint, latest_position, lag_events, ...}. Older
            %% code paths emitted #{lag, latest_version, ...}. Accept
            %% both shapes here so the gateway is robust across
            %% reckon-db versions.
            Checkpoint     = maps:get(checkpoint, LagInfo, 0),
            LatestPosition = maps:get(latest_position,
                                      LagInfo,
                                      maps:get(latest_version, LagInfo, 0)),
            LagEvents      = maps:get(lag_events,
                                      LagInfo,
                                      maps:get(lag, LagInfo, 0)),
            {ok, #{lag => LagEvents,
                   current_checkpoint => Checkpoint,
                   latest_version => LatestPosition}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

%%====================================================================
%% Internal
%%====================================================================

stream_events_loop(Stream, StoreId, Name) ->
    receive
        {events, Events} when is_list(Events) ->
            %% grpc_stream:reply/2 returns `ok', not a Stream — don't
            %% thread the accumulator through foldl or the second
            %% iteration calls `reply(ok, _)' and crashes the handler
            %% with function_clause. Stream stays valid for the
            %% lifetime of the HTTP/2 stream.
            lists:foreach(
                fun(Event) ->
                    Recorded = reckon_gateway_convert:event_to_recorded(Event),
                    Msg = #{event => Recorded, checkpoint => Event#event.version},
                    grpc_stream:reply(Stream, Msg)
                end,
                Events),
            stream_events_loop(Stream, StoreId, Name);
        stop ->
            {ok, Stream};
        {'EXIT', _Pid, _Reason} ->
            {ok, Stream}
    end.
