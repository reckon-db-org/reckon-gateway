%% @doc gRPC StreamService implementation (emqx/grpc-erl).
%%
%% Catalogue mode: every reckon_gater_api call goes through
%% reckon_gateway_dispatch, which looks up the owning cluster +
%% rpc-invokes the API function on the BEAM that holds the store.
%%
%% Errors from dispatch are routed through reckon_gateway_error
%% to ensure the underlying reason is logged server-side (the
%% grpc-erl unary interface drops `grpc-message' — see that
%% module's docstring for the FIXME reference).
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
    read_by_metadata/2,
    read_all_global/2
]).

append_events(#{store_id := StoreIdBin,
                stream_id := StreamId,
                expected_version := ExpectedVersion,
                events := ProposedEvents}, Md) ->
    with_store_id(StoreIdBin, append_events,
        fun(StoreId) -> append_reply(StoreId, StreamId, ExpectedVersion, ProposedEvents, Md) end).

append_reply(StoreId, StreamId, ExpectedVersion, ProposedEvents, Md) ->
    Events = [reckon_gateway_convert:proposed_to_event(E, StreamId) || E <- ProposedEvents],
    append_result(
        reckon_gateway_dispatch:call(append_events, [StoreId, StreamId, ExpectedVersion, Events]),
        length(Events), Md).

append_result({ok, NewVersion}, Count, Md) ->
    {ok, #{version => NewVersion, position => 0, count => Count}, Md};
append_result({error, Reason}, _Count, _Md) ->
    reckon_gateway_error:wrap(append_events, <<"3">>, Reason).

read_stream_forward(#{store_id := StoreIdBin,
                      stream_id := StreamId,
                      start_version := StartVersion,
                      count := Count}, Md) ->
    with_store_id(StoreIdBin, read_stream_forward,
        fun(StoreId) ->
            recorded_reply(
                reckon_gateway_dispatch:call(stream_forward,
                    [StoreId, StreamId, StartVersion, safe_count(Count)]),
                read_stream_forward, <<"5">>, Md)
        end).

read_stream_backward(#{store_id := StoreIdBin,
                       stream_id := StreamId,
                       start_version := StartVersion,
                       count := Count}, Md) ->
    with_store_id(StoreIdBin, read_stream_backward,
        fun(StoreId) ->
            recorded_reply(
                reckon_gateway_dispatch:call(stream_backward,
                    [StoreId, StreamId, StartVersion, safe_count(Count)]),
                read_stream_backward, <<"5">>, Md)
        end).

%% Server-streaming: emqx/grpc-erl calls Fun(Stream, Metadata).
%% Error path is 3-tuple `{Code, Message, Stream}'; the message
%% actually reaches the client over grpc-message.
stream_events_forward(Stream, _Md) ->
    {more, [Request], Stream1} = grpc_stream:recv(Stream),
    #{store_id := StoreIdBin,
      stream_id := StreamId,
      start_version := StartVersion,
      count := Count} = Request,
    stream_forward_resolve(reckon_gateway_convert:try_store_id(StoreIdBin),
                           StreamId, StartVersion, Count, Stream1).

stream_forward_resolve({error, invalid_store_id}, _StreamId, _StartVersion, _Count, Stream1) ->
    {Code, Msg} = reckon_gateway_error:wrap_stream(
        stream_events_forward, <<"3">>, invalid_store_id),
    {Code, Msg, Stream1};
stream_forward_resolve({ok, StoreId}, StreamId, StartVersion, Count, Stream1) ->
    stream_forward_send(
        reckon_gateway_dispatch:call(stream_forward,
            [StoreId, StreamId, StartVersion, safe_count(Count)]),
        Stream1).

stream_forward_send({ok, Events}, Stream1) ->
    lists:foreach(fun(E) -> stream_reply_event(Stream1, E) end, Events),
    {ok, Stream1};
stream_forward_send({error, Reason}, Stream1) ->
    {Code, Msg} = reckon_gateway_error:wrap_stream(
        stream_events_forward, <<"5">>, Reason),
    {Code, Msg, Stream1}.

stream_reply_event(Stream1, E) ->
    grpc_stream:reply(Stream1, reckon_gateway_convert:event_to_recorded(E)).

get_stream_version(#{store_id := StoreIdBin,
                     stream_id := StreamId}, Md) ->
    with_store_id(StoreIdBin, get_stream_version,
        fun(StoreId) ->
            version_reply(reckon_gateway_dispatch:call(get_version, [StoreId, StreamId]), Md)
        end).

version_reply({ok, Version}, Md) ->
    {ok, #{version => Version}, Md};
version_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(get_stream_version, <<"5">>, Reason).

list_streams(#{store_id := StoreIdBin}, Md) ->
    with_store_id(StoreIdBin, list_streams,
        fun(StoreId) -> list_reply(reckon_gateway_dispatch:call(get_streams, [StoreId]), Md) end).

list_reply({ok, Streams}, Md) ->
    {ok, #{stream_ids => Streams}, Md};
list_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(list_streams, <<"13">>, Reason).

delete_stream(#{store_id := StoreIdBin,
                stream_id := StreamId}, Md) ->
    with_store_id(StoreIdBin, delete_stream,
        fun(StoreId) ->
            delete_reply(reckon_gateway_dispatch:call(delete_stream, [StoreId, StreamId]), Md)
        end).

delete_reply(ok, Md) ->
    {ok, #{}, Md};
delete_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(delete_stream, <<"13">>, Reason).

read_by_event_types(#{store_id := StoreIdBin,
                      event_types := EventTypes,
                      batch_size := BatchSize}, Md) ->
    with_store_id(StoreIdBin, read_by_event_types,
        fun(StoreId) ->
            recorded_reply(
                reckon_gateway_dispatch:call(read_by_event_types,
                    [StoreId, EventTypes, safe_count(BatchSize)]),
                read_by_event_types, <<"13">>, Md)
        end).

read_by_tags(#{store_id := StoreIdBin,
               tags := Tags,
               match := Match,
               batch_size := BatchSize}, Md) ->
    with_store_id(StoreIdBin, read_by_tags,
        fun(StoreId) -> tags_reply(StoreId, Tags, Match, BatchSize, Md) end).

tags_reply(StoreId, Tags, Match, BatchSize, Md) ->
    Opts = #{match => match_atom(Match), batch_size => safe_count(BatchSize)},
    recorded_reply(reckon_gateway_dispatch:call(read_by_tags, [StoreId, Tags, Opts]),
                   read_by_tags, <<"13">>, Md).

match_atom('TAG_MATCH_ALL') -> all;
match_atom(_)               -> any.

read_by_metadata(#{store_id := StoreIdBin,
                   key := Key,
                   value := Value,
                   batch_size := BatchSize}, Md) ->
    %% reckon_gater_api:read_by_metadata/3 returns all matches;
    %% bound the wire response by batch_size at the gateway.
    with_store_id(StoreIdBin, read_by_metadata,
        fun(StoreId) ->
            metadata_reply(
                reckon_gateway_dispatch:call(read_by_metadata, [StoreId, Key, Value]),
                BatchSize, Md)
        end).

metadata_reply({ok, Events}, BatchSize, Md) ->
    Limited = lists:sublist(Events, safe_count(BatchSize)),
    {ok, #{events => [reckon_gateway_convert:event_to_recorded(E) || E <- Limited]}, Md};
metadata_reply({error, Reason}, _BatchSize, _Md) ->
    reckon_gateway_error:wrap(read_by_metadata, <<"13">>, Reason).

read_all_global(#{store_id := StoreIdBin,
                  offset := Offset,
                  limit := Limit}, Md) ->
    with_store_id(StoreIdBin, read_all_global,
        fun(StoreId) ->
            recorded_reply(
                reckon_gateway_dispatch:call(read_all_global, [StoreId, Offset, safe_count(Limit)]),
                read_all_global, <<"13">>, Md)
        end).

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

%% @private Map a dispatch result of recorded events to the proto
%% reply, or wrap the error under ErrFn/Code.
recorded_reply({ok, Events}, _ErrFn, _Code, Md) ->
    {ok, #{events => [reckon_gateway_convert:event_to_recorded(E) || E <- Events]}, Md};
recorded_reply({error, Reason}, ErrFn, Code, _Md) ->
    reckon_gateway_error:wrap(ErrFn, Code, Reason).

-define(MAX_READ_COUNT, 10000).

safe_count(0) -> ?MAX_READ_COUNT;
safe_count(N) when N > ?MAX_READ_COUNT -> ?MAX_READ_COUNT;
safe_count(N) -> N.
