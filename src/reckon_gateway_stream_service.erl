%% @doc gRPC StreamService implementation.
%%
%% Delegates all stream operations to esdb_gater_api.
-module(reckon_gateway_stream_service).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-behaviour(reckon_gateway_v_1_stream_service_bhvr).

-export([
    append_events/2,
    read_stream_forward/2,
    read_stream_backward/2,
    stream_events_forward/2,
    get_stream_version/2,
    list_streams/2,
    delete_stream/2,
    read_by_event_types/2,
    read_by_tags/2,
    read_all_global/2
]).

append_events(Ctx, #{store_id := StoreIdBin,
                     stream_id := StreamId,
                     expected_version := ExpectedVersion,
                     events := ProposedEvents}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    Events = [reckon_gateway_convert:proposed_to_event(E, StreamId)
              || E <- ProposedEvents],
    case esdb_gater_api:append_events(StoreId, StreamId, ExpectedVersion, Events) of
        {ok, NewVersion} ->
            {ok, #{version => NewVersion,
                   position => 0,
                   count => length(Events)}, Ctx};
        {error, {wrong_expected_version, Expected, Actual}} ->
            {grpc_error, {<<"3">>, iolist_to_binary(
                io_lib:format("wrong expected version: expected ~p, got ~p",
                              [Expected, Actual]))}};
        {error, {wrong_expected_version, CurrentVersion}} ->
            {grpc_error, {<<"3">>, iolist_to_binary(
                io_lib:format("wrong expected version: current ~p",
                              [CurrentVersion]))}};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

read_stream_forward(Ctx, #{store_id := StoreIdBin,
                           stream_id := StreamId,
                           start_version := StartVersion,
                           count := Count}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SafeCount = safe_count(Count),
    case esdb_gater_api:stream_forward(StoreId, StreamId, StartVersion, SafeCount) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

read_stream_backward(Ctx, #{store_id := StoreIdBin,
                            stream_id := StreamId,
                            start_version := StartVersion,
                            count := Count}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SafeCount = safe_count(Count),
    case esdb_gater_api:stream_backward(StoreId, StreamId, StartVersion, SafeCount) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

%% Server-streaming: sends events one at a time.
%% grpcbox server-streaming callback: (Request, Stream) -> ok
stream_events_forward(#{store_id := StoreIdBin,
                        stream_id := StreamId,
                        start_version := StartVersion,
                        count := Count}, Stream) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:stream_forward(StoreId, StreamId, StartVersion, Count) of
        {ok, Events} ->
            lists:foreach(
                fun(E) ->
                    Recorded = reckon_gateway_convert:event_to_recorded(E),
                    grpcbox_stream:send(Recorded, Stream)
                end, Events),
            ok;
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

get_stream_version(Ctx, #{store_id := StoreIdBin,
                          stream_id := StreamId}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_version(StoreId, StreamId) of
        {ok, Version} ->
            {ok, #{version => Version}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

list_streams(Ctx, #{store_id := StoreIdBin}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_streams(StoreId) of
        {ok, Streams} ->
            {ok, #{stream_ids => Streams}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

delete_stream(Ctx, #{store_id := StoreIdBin,
                     stream_id := StreamId}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:delete_stream(StoreId, StreamId) of
        ok ->
            {ok, #{}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

read_by_event_types(Ctx, #{store_id := StoreIdBin,
                           event_types := EventTypes,
                           batch_size := BatchSize}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    BS = case BatchSize of 0 -> 1000; _ -> BatchSize end,
    case esdb_gater_api:read_by_event_types(StoreId, EventTypes, BS) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

read_by_tags(Ctx, #{store_id := StoreIdBin,
                    tags := Tags,
                    match := Match,
                    batch_size := BatchSize}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    MatchAtom = case Match of
        'TAG_MATCH_ALL' -> all;
        _ -> any
    end,
    Opts = #{match => MatchAtom,
             batch_size => case BatchSize of 0 -> 1000; _ -> BatchSize end},
    case esdb_gater_api:read_by_tags(StoreId, Tags, Opts) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

read_all_global(Ctx, #{store_id := StoreIdBin,
                       offset := Offset,
                       limit := Limit}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    L = safe_count(Limit),
    case esdb_gater_api:read_all_global(StoreId, Offset, L) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

%%====================================================================
%% Internal
%%====================================================================

%% Cap read count to prevent OOM on unbounded reads.
%% Clients wanting more should paginate.
-define(MAX_READ_COUNT, 10000).

safe_count(0) -> ?MAX_READ_COUNT;
safe_count(N) when N > ?MAX_READ_COUNT -> ?MAX_READ_COUNT;
safe_count(N) -> N.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
