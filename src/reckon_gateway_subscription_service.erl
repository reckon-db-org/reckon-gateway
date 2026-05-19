%% @doc gRPC SubscriptionService implementation.
%%
%% Error paths routed through reckon_gateway_error so the
%% underlying reason is logged server-side (grpc-erl drops
%% grpc-message on unary; see reckon_gateway_error docstring).
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
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {Code, Msg} = reckon_gateway_error:wrap_stream(
                subscribe, <<"3">>, invalid_store_id),
            {Code, Msg, Stream1};
        {ok, StoreId} ->
            SubType = reckon_gateway_convert:subscription_type(Type),
            _PS = case PoolSize of 0 -> 1; _ -> PoolSize end,
            Self = self(),
            process_flag(trap_exit, true),
            case reckon_gateway_dispatch:call(save_subscription, [
                    StoreId, SubType, Selector, Name, StartFrom, Self]) of
                {ok, _Key} ->
                    try
                        stream_events_loop(Stream1, StoreId, Name)
                    after
                        %% Best-effort cleanup. remove_subscription is
                        %% idempotent (not_found → ok); the worker logs
                        %% any genuine error itself.
                        _ = reckon_gateway_dispatch:call(remove_subscription, [
                                StoreId, SubType, Selector, Name])
                    end;
                {error, Reason} ->
                    {Code, Msg} = reckon_gateway_error:wrap_stream(
                        subscribe, <<"3">>, {Name, Reason}),
                    {Code, Msg, Stream1}
            end
    end.

ack_event(#{store_id := StoreIdBin,
            stream_id := StreamId,
            subscription_name := Name,
            event_number := EventNumber}, Md) ->
    handle_ack(reckon_gateway_convert:try_store_id(StoreIdBin),
               StreamId, Name, EventNumber, Md).

handle_ack({error, invalid_store_id}, _StreamId, _Name, _EvtNum, _Md) ->
    reckon_gateway_error:wrap(ack_event, <<"3">>, invalid_store_id);
handle_ack({ok, StoreId}, StreamId, Name, EventNumber, Md) ->
    AckMap = #{event_number => EventNumber},
    reply_ack(reckon_gateway_dispatch:call(ack_event, [StoreId, StreamId, self(), AckMap]), Name, Md).

reply_ack(ok, _Name, Md) ->
    {ok, #{}, Md};
reply_ack({error, Reason}, Name, _Md) ->
    reckon_gateway_error:wrap(ack_event, <<"3">>, {Name, Reason}).

create_subscription(#{store_id := StoreIdBin,
                      type := Type,
                      selector := Selector,
                      subscription_name := Name,
                      start_from := StartFrom,
                      pool_size := PoolSize}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(create_subscription, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            SubType = reckon_gateway_convert:subscription_type(Type),
            _PS = case PoolSize of 0 -> 1; _ -> PoolSize end,
            case reckon_gateway_dispatch:call(save_subscription, [
                    StoreId, SubType, Selector, Name, StartFrom, undefined]) of
                {ok, _Key} ->
                    SubId = iolist_to_binary(
                        [atom_to_binary(StoreId), <<":">>, Name]),
                    {ok, #{subscription_id => SubId}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(create_subscription, <<"3">>, {Name, Reason})
            end
    end.

remove_subscription(#{store_id := StoreIdBin,
                      type := Type,
                      selector := Selector,
                      subscription_name := Name}, Md) ->
    handle_remove(reckon_gateway_convert:try_store_id(StoreIdBin),
                  Type, Selector, Name, Md).

handle_remove({error, invalid_store_id}, _Type, _Sel, _Name, _Md) ->
    reckon_gateway_error:wrap(remove_subscription, <<"3">>, invalid_store_id);
handle_remove({ok, StoreId}, Type, Selector, Name, Md) ->
    SubType = reckon_gateway_convert:subscription_type(Type),
    reply_remove(reckon_gateway_dispatch:call(remove_subscription, [StoreId, SubType, Selector, Name]),
                 Name, Md).

reply_remove(ok, _Name, Md) ->
    {ok, #{}, Md};
reply_remove({error, Reason}, Name, _Md) ->
    reckon_gateway_error:wrap(remove_subscription, <<"3">>, {Name, Reason}).

list_subscriptions(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(list_subscriptions, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(get_subscriptions, [StoreId]) of
                {ok, Subs} ->
                    ProtoSubs = [reckon_gateway_convert:subscription_to_proto(S) || S <- Subs],
                    {ok, #{subscriptions => ProtoSubs}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(list_subscriptions, <<"13">>, Reason)
            end
    end.

get_subscription(#{store_id := StoreIdBin,
                   subscription_name := Name}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(get_subscription, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(get_subscription, [StoreId, Name]) of
                {ok, Sub} ->
                    {ok, reckon_gateway_convert:subscription_to_proto(Sub), Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(get_subscription, <<"5">>, {Name, Reason})
            end
    end.

get_subscription_lag(#{store_id := StoreIdBin,
                       subscription_name := Name}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(get_subscription_lag, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(subscription_lag, [StoreId, Name]) of
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
                {error, Reason} ->
                    reckon_gateway_error:wrap(get_subscription_lag, <<"13">>, {Name, Reason})
            end
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
