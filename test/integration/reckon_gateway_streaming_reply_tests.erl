%%% @doc Gate for a server-streaming RPC over the real HTTP/2 stack.
%%%
%%% `StreamEventsForward' answers with N replies and then ends the stream
%%% with a `{trailers, _}' frame carrying `grpc-status'. That final frame is
%%% the part no unit test can see: it is produced by cowboy/cowlib, not by
%%% this repository's handler, and the emqx/cowboy fork the gRPC runtime used
%%% to drag in routes it through cowlib's `send_or_queue_data', which has no
%%% clause for trailers and raises `case_clause' instead. The client then
%%% never receives the end of its stream and every server-streaming call dies
%%% on the last frame, looking like an application error.
%%%
%%% So this test drives the real listener on an ephemeral port with the real
%%% generated client and asserts the three things a broken trailer path takes
%%% away: the replies arrive, the stream ends with an `{eos, Trailers}' frame,
%%% and that frame says `grpc-status: 0'.
%%%
%%% Only the cluster behind the handler is stubbed (reckon_gateway_dispatch),
%%% so the frame path under test is exactly the one a client meets in
%%% production.
-module(reckon_gateway_streaming_reply_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-define(LISTENER, reckon_gateway_streaming_reply_gate).
-define(CHANNEL, reckon_gateway_streaming_reply_gate_channel).
-define(STORE_ID, <<"test_store">>).
-define(STREAM_ID, <<"stream-1">>).
-define(TIMEOUT, 10000).
-define(MAX_READS, 20).

streaming_reply_ends_with_trailers_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     fun(_SetupData) -> ?_test(stream_and_assert()) end}.

stream_and_assert() ->
    {Replies, Trailers} = read_whole_stream(),
    ?assertEqual([0, 1, 2], [maps:get(version, R) || R <- Replies]),
    ?assertEqual([<<"ev-0">>, <<"ev-1">>, <<"ev-2">>],
                 [maps:get(event_id, R) || R <- Replies]),
    %% The stream ended because the server said so, not because the
    %% connection died: that is what the trailers frame proves.
    ?assertEqual(<<"0">>, proplists:get_value(<<"grpc-status">>, Trailers)).

setup() ->
    {ok, _} = application:ensure_all_started(grpc),
    ok = meck:new(reckon_gateway_dispatch, [passthrough]),
    ok = meck:expect(reckon_gateway_dispatch, call,
                     fun(stream_forward, [_StoreId, _StreamId, _Start, _Count]) ->
                             {ok, events()};
                        (F, A) ->
                             meck:passthrough([F, A])
                     end),
    {ok, _} = grpc:start_server(?LISTENER, 0, services(), [{enable_default_services, []}]),
    Port = ranch:get_port(?LISTENER),
    {ok, _} = grpc_client_sup:create_channel_pool(
                ?CHANNEL, "http://127.0.0.1:" ++ integer_to_list(Port), #{pool_size => 1}),
    ok.

cleanup(_) ->
    ok = grpc_client_sup:stop_channel_pool(?CHANNEL),
    ok = grpc:stop_server(?LISTENER),
    ok = meck:unload(reckon_gateway_dispatch).

services() ->
    #{protos => [reckon_streams_pb],
      services => #{'reckon.gateway.v1.StreamService' => reckon_gateway_stream_service}}.

%%%===================================================================
%%% Reading a whole server stream
%%%===================================================================

read_whole_stream() ->
    {ok, Stream} = reckon_gateway_v_1_stream_service_client:stream_events_forward(
                     #{}, #{channel => ?CHANNEL, timeout => ?TIMEOUT}),
    ok = grpc_client:send(Stream, request(), fin),
    collect(Stream, [], ?MAX_READS).

%% The replies and the trailers frame can arrive in one read or in two,
%% so this reads until the server's end-of-stream frame shows up.
collect(_Stream, Acc, 0) ->
    error({stream_never_reached_its_trailers, Acc});
collect(Stream, Acc, Reads) ->
    case read_frames(Stream) of
        {[{eos, Trailers}], Replies} -> {Acc ++ Replies, Trailers};
        {[], Replies} -> collect(Stream, Acc ++ Replies, Reads - 1)
    end.

read_frames(Stream) ->
    case grpc_client:recv(Stream, ?TIMEOUT) of
        {ok, Frames} ->
            lists:partition(fun is_eos/1, Frames);
        {error, Reason} ->
            error({stream_did_not_reach_its_trailers, Reason})
    end.

is_eos(Frame) ->
    is_tuple(Frame) andalso element(1, Frame) =:= eos.

%%%===================================================================
%%% Fixtures
%%%===================================================================

request() ->
    #{store_id => ?STORE_ID,
      stream_id => ?STREAM_ID,
      start_version => 0,
      count => length(events())}.

events() ->
    [event(0, <<"game_started">>),
     event(1, <<"move_played">>),
     event(2, <<"game_ended">>)].

event(Version, Type) ->
    #event{
        event_id = iolist_to_binary(io_lib:format("ev-~p", [Version])),
        event_type = Type,
        stream_id = ?STREAM_ID,
        version = Version,
        data = #{},
        metadata = #{},
        tags = [],
        timestamp = 0,
        epoch_us = 0
    }.
