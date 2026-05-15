%% @doc gRPC StreamService implementation (emqx/grpc-erl).
%%
%% Delegates all stream operations to reckon_gater_api.
-module(reckon_gateway_stream_service).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").

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

append_events(#{store_id := StoreIdBin,
                stream_id := StreamId,
                expected_version := ExpectedVersion,
                events := ProposedEvents}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    Events = [reckon_gateway_convert:proposed_to_event(E, StreamId)
              || E <- ProposedEvents],
    case reckon_gater_api:append_events(StoreId, StreamId, ExpectedVersion, Events) of
        {ok, NewVersion} ->
            {ok, #{version => NewVersion,
                   position => 0,
                   count => length(Events)}, Md};
        {error, _Reason} ->
            {error, <<"3">>}
    end.

read_stream_forward(#{store_id := StoreIdBin,
                      stream_id := StreamId,
                      start_version := StartVersion,
                      count := Count}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SafeCount = safe_count(Count),
    case reckon_gater_api:stream_forward(StoreId, StreamId, StartVersion, SafeCount) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"5">>}
    end.

read_stream_backward(#{store_id := StoreIdBin,
                       stream_id := StreamId,
                       start_version := StartVersion,
                       count := Count}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SafeCount = safe_count(Count),
    case reckon_gater_api:stream_backward(StoreId, StreamId, StartVersion, SafeCount) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"5">>}
    end.

%% Server-streaming: emqx/grpc-erl calls Fun(Stream, Metadata)
stream_events_forward(Stream, _Md) ->
    {more, [Request], Stream1} = grpc_stream:recv(Stream),
    #{store_id := StoreIdBin,
      stream_id := StreamId,
      start_version := StartVersion,
      count := Count} = Request,
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SafeCount = safe_count(Count),
    case reckon_gater_api:stream_forward(StoreId, StreamId, StartVersion, SafeCount) of
        {ok, Events} ->
            lists:foreach(
                fun(E) ->
                    grpc_stream:reply(Stream1,
                        reckon_gateway_convert:event_to_recorded(E))
                end, Events),
            {ok, Stream1};
        {error, _Reason} ->
            {<<"5">>, <<"stream read failed">>, Stream1}
    end.

get_stream_version(#{store_id := StoreIdBin,
                     stream_id := StreamId}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:get_version(StoreId, StreamId) of
        {ok, Version} ->
            {ok, #{version => Version}, Md};
        {error, _Reason} ->
            {error, <<"5">>}
    end.

list_streams(#{store_id := StoreIdBin}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:get_streams(StoreId) of
        {ok, Streams} ->
            {ok, #{stream_ids => Streams}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

delete_stream(#{store_id := StoreIdBin,
                stream_id := StreamId}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:delete_stream(StoreId, StreamId) of
        ok ->
            {ok, #{}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

read_by_event_types(#{store_id := StoreIdBin,
                      event_types := EventTypes,
                      batch_size := BatchSize}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    BS = safe_count(BatchSize),
    case reckon_gater_api:read_by_event_types(StoreId, EventTypes, BS) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

read_by_tags(#{store_id := StoreIdBin,
               tags := Tags,
               match := Match,
               batch_size := BatchSize}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    MatchAtom = case Match of
        'TAG_MATCH_ALL' -> all;
        _ -> any
    end,
    Opts = #{match => MatchAtom, batch_size => safe_count(BatchSize)},
    case reckon_gater_api:read_by_tags(StoreId, Tags, Opts) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

read_all_global(#{store_id := StoreIdBin,
                  offset := Offset,
                  limit := Limit}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    L = safe_count(Limit),
    case reckon_gater_api:read_all_global(StoreId, Offset, L) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

%%====================================================================
%% Internal
%%====================================================================

-define(MAX_READ_COUNT, 10000).

safe_count(0) -> ?MAX_READ_COUNT;
safe_count(N) when N > ?MAX_READ_COUNT -> ?MAX_READ_COUNT;
safe_count(N) -> N.
