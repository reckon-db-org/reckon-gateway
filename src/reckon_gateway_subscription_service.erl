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
           pool_size := _PoolSize}], Stream1} = grpc_stream:recv(Stream),
    subscribe_resolve(reckon_gateway_convert:try_store_id(StoreIdBin),
                      Type, Selector, Name, StartFrom, Stream1).

subscribe_resolve({error, invalid_store_id}, _Type, _Selector, _Name, _StartFrom, Stream1) ->
    {Code, Msg} = reckon_gateway_error:wrap_stream(subscribe, <<"3">>, invalid_store_id),
    {Code, Msg, Stream1};
subscribe_resolve({ok, StoreId}, Type, Selector, Name, StartFrom, Stream1) ->
    SubType = reckon_gateway_convert:subscription_type(Type),
    Self = self(),
    process_flag(trap_exit, true),
    subscribe_saved(
        reckon_gateway_dispatch:call(save_subscription,
            [StoreId, SubType, Selector, Name, StartFrom, Self]),
        StoreId, SubType, Selector, Name, Stream1).

subscribe_saved({ok, _Key}, StoreId, SubType, Selector, Name, Stream1) ->
    try
        stream_events_loop(Stream1, StoreId, Name)
    after
        %% Best-effort cleanup. remove_subscription is idempotent
        %% (not_found → ok); the worker logs any genuine error itself.
        _ = reckon_gateway_dispatch:call(remove_subscription, [StoreId, SubType, Selector, Name])
    end;
subscribe_saved({error, Reason}, _StoreId, _SubType, _Selector, Name, Stream1) ->
    {Code, Msg} = reckon_gateway_error:wrap_stream(subscribe, <<"3">>, {Name, Reason}),
    {Code, Msg, Stream1}.

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
                      pool_size := _PoolSize}, Md) ->
    with_store_id(StoreIdBin, create_subscription,
        fun(StoreId) -> create_sub_reply(StoreId, Type, Selector, Name, StartFrom, Md) end).

create_sub_reply(StoreId, Type, Selector, Name, StartFrom, Md) ->
    SubType = reckon_gateway_convert:subscription_type(Type),
    save_sub_result(
        reckon_gateway_dispatch:call(save_subscription,
            [StoreId, SubType, Selector, Name, StartFrom, undefined]),
        StoreId, Name, Md).

save_sub_result({ok, _Key}, StoreId, Name, Md) ->
    SubId = iolist_to_binary([atom_to_binary(StoreId), <<":">>, Name]),
    {ok, #{subscription_id => SubId}, Md};
save_sub_result({error, Reason}, _StoreId, Name, _Md) ->
    reckon_gateway_error:wrap(create_subscription, <<"3">>, {Name, Reason}).

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
    with_store_id(StoreIdBin, list_subscriptions,
        fun(StoreId) ->
            list_subs_reply(reckon_gateway_dispatch:call(get_subscriptions, [StoreId]), Md)
        end).

list_subs_reply({ok, Subs}, Md) ->
    {ok, #{subscriptions => [reckon_gateway_convert:subscription_to_proto(S) || S <- Subs]}, Md};
list_subs_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(list_subscriptions, <<"13">>, Reason).

get_subscription(#{store_id := StoreIdBin,
                   subscription_name := Name}, Md) ->
    with_store_id(StoreIdBin, get_subscription,
        fun(StoreId) ->
            get_sub_reply(reckon_gateway_dispatch:call(get_subscription, [StoreId, Name]), Name, Md)
        end).

get_sub_reply({ok, Sub}, _Name, Md) ->
    {ok, reckon_gateway_convert:subscription_to_proto(Sub), Md};
get_sub_reply({error, Reason}, Name, _Md) ->
    reckon_gateway_error:wrap(get_subscription, <<"5">>, {Name, Reason}).

get_subscription_lag(#{store_id := StoreIdBin,
                       subscription_name := Name}, Md) ->
    with_store_id(StoreIdBin, get_subscription_lag,
        fun(StoreId) ->
            lag_reply(reckon_gateway_dispatch:call(subscription_lag, [StoreId, Name]), Name, Md)
        end).

%% @private reckon_db_store_inspector:subscription_lag/2 returns
%% #{checkpoint, latest_position, lag_events, ...}. Older code paths
%% emitted #{lag, latest_version, ...}. Accept both shapes so the
%% gateway is robust across reckon-db versions. Coerce to non-neg
%% integers: these are uint64 proto fields, and reckon_db can hand back
%% `undefined` for an $all/system-stream sub; encoding a non-integer
%% corrupts gpb output ("invalid wire-format data").
lag_reply({ok, LagInfo}, _Name, Md) ->
    Checkpoint     = maps:get(checkpoint, LagInfo, 0),
    LatestPosition = maps:get(latest_position, LagInfo, maps:get(latest_version, LagInfo, 0)),
    LagEvents      = maps:get(lag_events, LagInfo, maps:get(lag, LagInfo, 0)),
    {ok, #{lag => to_uint(LagEvents),
           current_checkpoint => to_uint(Checkpoint),
           latest_version => to_uint(LatestPosition)}, Md};
lag_reply({error, Reason}, Name, _Md) ->
    reckon_gateway_error:wrap(get_subscription_lag, <<"13">>, {Name, Reason}).

%%====================================================================
%% Internal
%%====================================================================

%% @private Resolve a store-id binary, wrapping the canonical
%% invalid_store_id gRPC error, then run Fun with the parsed id.
with_store_id(StoreIdBin, ErrFn, Fun) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(ErrFn, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            Fun(StoreId)
    end.

%% Force a value into the non-negative integer domain of a uint64 proto
%% field. undefined / negative / non-integer all collapse to 0.
to_uint(N) when is_integer(N), N >= 0 -> N;
to_uint(_)                            -> 0.

stream_events_loop(Stream, StoreId, Name) ->
    receive
        {events, Events} when is_list(Events) ->
            reply_events(Stream, Events),
            stream_events_loop(Stream, StoreId, Name);
        stop ->
            {ok, Stream};
        {'EXIT', _Pid, _Reason} ->
            {ok, Stream}
    end.

%% @private grpc_stream:reply/2 returns `ok', not a Stream — don't
%% thread the accumulator through foldl or the second iteration calls
%% `reply(ok, _)' and crashes the handler with function_clause. Stream
%% stays valid for the lifetime of the HTTP/2 stream.
reply_events(Stream, Events) ->
    lists:foreach(fun(Event) -> reply_event(Stream, Event) end, Events).

reply_event(Stream, Event) ->
    Recorded = reckon_gateway_convert:event_to_recorded(Event),
    Msg = #{event => Recorded, checkpoint => Event#event.version},
    grpc_stream:reply(Stream, Msg).
