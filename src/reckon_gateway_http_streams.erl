%%% @doc HTTP/JSON handlers for StreamService operations.
%%%
%%% Routes (all under /v1/stores/:store_id/):
%%%
%%%   GET    /streams                         list_streams
%%%   DELETE /streams/:stream_id              delete_stream
%%%   POST   /streams/:stream_id/events       append_events
%%%   GET    /streams/:stream_id/events       read_stream_forward (dir=backward reverses)
%%%   GET    /streams/:stream_id/version      get_stream_version
%%%   GET    /events/by-type?types=a,b        read_by_event_types
%%%   GET    /events/by-tags?tags=a,b&match=  read_by_tags
%%%   GET    /events/by-metadata?key=&value=  read_by_metadata
%%%   GET    /events/global?offset=&limit=    read_all_global
-module(reckon_gateway_http_streams).

-behaviour(cowboy_handler).

-export([init/2]).

init(Req0, #{op := Op} = State) ->
    Req = handle(cowboy_req:method(Req0), Op, Req0),
    {ok, Req, State}.

%%====================================================================
%% Dispatch
%%====================================================================

handle(<<"OPTIONS">>, _Op, Req) ->
    reckon_gateway_http:cors_preflight(Req);

%% List streams
handle(<<"GET">>, list, Req) ->
    with_store(Req, fun handle_list/2);

%% Delete stream
handle(<<"DELETE">>, stream, Req) ->
    StreamId = cowboy_req:binding(stream_id, Req),
    with_store(Req, fun(StoreId, R) -> handle_delete(StoreId, R, StreamId) end);

%% Append events
handle(<<"POST">>, events, Req0) ->
    StreamId = cowboy_req:binding(stream_id, Req0),
    with_store(Req0, fun(StoreId, R0) -> handle_append(StoreId, R0, StreamId) end);

%% Read events (forward or backward)
handle(<<"GET">>, events, Req) ->
    StreamId = cowboy_req:binding(stream_id, Req),
    From  = reckon_gateway_http:qs_int(Req, from, 0),
    Limit = reckon_gateway_http:qs_int(Req, limit, 100),
    Op    = read_dir_op(reckon_gateway_http:qs_binary(Req, dir, <<"forward">>)),
    with_store(Req, fun(StoreId, R) -> handle_read(StoreId, R, Op, StreamId, From, Limit) end);

%% Stream version
handle(<<"GET">>, version, Req) ->
    StreamId = cowboy_req:binding(stream_id, Req),
    with_store(Req, fun(StoreId, R) -> handle_version(StoreId, R, StreamId) end);

%% Read by event types: ?types=a,b,c&limit=N
handle(<<"GET">>, by_type, Req) ->
    Types = reckon_gateway_http:qs_list(Req, types, []),
    Limit = reckon_gateway_http:qs_int(Req, limit, 0),
    with_store(Req, fun(StoreId, R) -> handle_by_type(StoreId, R, Types, Limit) end);

%% Read by tags: ?tags=a,b&match=any|all&limit=N
handle(<<"GET">>, by_tags, Req) ->
    Tags  = reckon_gateway_http:qs_list(Req, tags, []),
    Limit = reckon_gateway_http:qs_int(Req, limit, 0),
    MatchAtom = match_atom(reckon_gateway_http:qs_binary(Req, match, <<"any">>)),
    with_store(Req, fun(StoreId, R) -> handle_by_tags(StoreId, R, Tags, MatchAtom, Limit) end);

%% Read by metadata: ?key=K&value=V&limit=N
handle(<<"GET">>, by_metadata, Req) ->
    Key   = reckon_gateway_http:qs_binary(Req, key, undefined),
    Value = reckon_gateway_http:qs_binary(Req, value, undefined),
    Limit = reckon_gateway_http:qs_int(Req, limit, 0),
    with_store(Req, fun(StoreId, R) -> handle_by_metadata(StoreId, R, Key, Value, Limit) end);

%% Read global: ?offset=N&limit=N
handle(<<"GET">>, global, Req) ->
    Offset = reckon_gateway_http:qs_int(Req, offset, 0),
    Limit  = reckon_gateway_http:qs_int(Req, limit, 100),
    with_store(Req, fun(StoreId, R) -> handle_global(StoreId, R, Offset, Limit) end);

handle(Method, Op, Req) ->
    reckon_gateway_http:reply_error(405,
        iolist_to_binary(io_lib:format("~s not allowed for ~p", [Method, Op])), Req).

%%====================================================================
%% Internal
%%====================================================================

with_store(Req, Fun) ->
    StoreIdBin = cowboy_req:binding(store_id, Req),
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_http:reply_error(400, <<"invalid_store_id">>, Req);
        {ok, StoreId} ->
            Fun(StoreId, Req)
    end.

handle_list(StoreId, R) ->
    case reckon_gateway_dispatch:call(get_streams, [StoreId]) of
        {ok, Streams} ->
            reckon_gateway_http:reply_json(200, #{<<"stream_ids">> => Streams}, R);
        {error, Reason} ->
            reckon_gateway_http:dispatch_error(Reason, R)
    end.

handle_delete(StoreId, R, StreamId) ->
    case reckon_gateway_dispatch:call(delete_stream, [StoreId, StreamId]) of
        ok              -> reckon_gateway_http:reply_json(200, #{<<"deleted">> => true}, R);
        {error, Reason} -> reckon_gateway_http:dispatch_error(Reason, R)
    end.

handle_append(StoreId, R0, StreamId) ->
    append_body(reckon_gateway_http:read_json_body(R0), StoreId, StreamId, R0).

append_body({error, invalid_json}, _StoreId, _StreamId, R0) ->
    reckon_gateway_http:reply_error(400, <<"invalid_json">>, R0);
append_body({ok, Body, R}, StoreId, StreamId, _R0) ->
    RawVersion = maps:get(<<"expected_version">>, Body, -2),
    Expected = reckon_gateway_http:parse_expected_version(RawVersion),
    RawEvents = maps:get(<<"events">>, Body, []),
    append_parsed(parse_proposed(RawEvents), StoreId, StreamId, Expected, R).

append_parsed({error, Reason}, _StoreId, _StreamId, _Expected, R) ->
    reckon_gateway_http:reply_error(400, Reason, R);
append_parsed({ok, Events}, StoreId, StreamId, Expected, R) ->
    append_result(
        reckon_gateway_dispatch:call(append_events, [StoreId, StreamId, Expected, Events]),
        length(Events), R).

append_result({ok, NewVersion}, Count, R) ->
    reckon_gateway_http:reply_json(200, #{<<"version">> => NewVersion, <<"count">> => Count}, R);
append_result({error, Reason}, _Count, R) ->
    reckon_gateway_http:dispatch_error(Reason, R).

read_dir_op(<<"backward">>) -> stream_backward;
read_dir_op(_)             -> stream_forward.

handle_read(StoreId, R, Op, StreamId, From, Limit) ->
    reply_events_count(reckon_gateway_dispatch:call(Op, [StoreId, StreamId, From, Limit]), R).

handle_version(StoreId, R, StreamId) ->
    case reckon_gateway_dispatch:call(get_version, [StoreId, StreamId]) of
        {ok, Version}   -> reckon_gateway_http:reply_json(200, #{<<"version">> => Version}, R);
        {error, Reason} -> reckon_gateway_http:dispatch_error(Reason, R)
    end.

handle_by_type(_StoreId, R, [], _Limit) ->
    reckon_gateway_http:reply_error(400, <<"missing types parameter">>, R);
handle_by_type(StoreId, R, Types, Limit) ->
    reply_events_count(
        reckon_gateway_dispatch:call(read_by_event_types, [StoreId, Types, Limit]), R).

match_atom(<<"all">>) -> all;
match_atom(_)         -> any.

handle_by_tags(_StoreId, R, [], _MatchAtom, _Limit) ->
    reckon_gateway_http:reply_error(400, <<"missing tags parameter">>, R);
handle_by_tags(StoreId, R, Tags, MatchAtom, Limit) ->
    Opts = #{match => MatchAtom, batch_size => Limit},
    reply_events_count(reckon_gateway_dispatch:call(read_by_tags, [StoreId, Tags, Opts]), R).

handle_by_metadata(_StoreId, R, undefined, _Value, _Limit) ->
    reckon_gateway_http:reply_error(400, <<"missing key parameter">>, R);
handle_by_metadata(_StoreId, R, _Key, undefined, _Limit) ->
    reckon_gateway_http:reply_error(400, <<"missing value parameter">>, R);
handle_by_metadata(StoreId, R, Key, Value, Limit) ->
    by_metadata_reply(reckon_gateway_dispatch:call(read_by_metadata, [StoreId, Key, Value]), Limit, R).

by_metadata_reply({ok, Events}, Limit, R) ->
    Limited = maybe_limit(Limit, Events),
    reckon_gateway_http:reply_json(200, #{
        <<"events">> => [reckon_gateway_http:event_to_json_map(E) || E <- Limited],
        <<"count">>  => length(Limited)
    }, R);
by_metadata_reply({error, Reason}, _Limit, R) ->
    reckon_gateway_http:dispatch_error(Reason, R).

maybe_limit(Limit, Events) when Limit > 0 -> lists:sublist(Events, Limit);
maybe_limit(_Limit, Events)               -> Events.

handle_global(StoreId, R, Offset, Limit) ->
    reply_events_count(reckon_gateway_dispatch:call(read_all_global, [StoreId, Offset, Limit]), R).

reply_events_count({ok, Events}, R) ->
    reckon_gateway_http:reply_json(200, #{
        <<"events">> => [reckon_gateway_http:event_to_json_map(E) || E <- Events],
        <<"count">>  => length(Events)
    }, R);
reply_events_count({error, Reason}, R) ->
    reckon_gateway_http:dispatch_error(Reason, R).

parse_proposed(RawEvents) when is_list(RawEvents) ->
    parse_proposed_loop(RawEvents, []);
parse_proposed(_) ->
    {error, <<"events must be an array">>}.

parse_proposed_loop([], Acc) ->
    {ok, lists:reverse(Acc)};
parse_proposed_loop([E | Rest], Acc) ->
    case reckon_gateway_http:proposed_from_json(E) of
        {error, Reason} -> {error, Reason};
        Event           -> parse_proposed_loop(Rest, [Event | Acc])
    end.
