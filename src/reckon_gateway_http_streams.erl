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
    with_store(Req, fun(StoreId, R) ->
        case reckon_gateway_dispatch:call(get_streams, [StoreId]) of
            {ok, Streams} ->
                reckon_gateway_http:reply_json(200, #{<<"stream_ids">> => Streams}, R);
            {error, Reason} ->
                reckon_gateway_http:dispatch_error(Reason, R)
        end
    end);

%% Delete stream
handle(<<"DELETE">>, stream, Req) ->
    StreamId = cowboy_req:binding(stream_id, Req),
    with_store(Req, fun(StoreId, R) ->
        case reckon_gateway_dispatch:call(delete_stream, [StoreId, StreamId]) of
            ok              -> reckon_gateway_http:reply_json(200, #{<<"deleted">> => true}, R);
            {error, Reason} -> reckon_gateway_http:dispatch_error(Reason, R)
        end
    end);

%% Append events
handle(<<"POST">>, events, Req0) ->
    StreamId = cowboy_req:binding(stream_id, Req0),
    with_store(Req0, fun(StoreId, R0) ->
        case reckon_gateway_http:read_json_body(R0) of
            {error, invalid_json} ->
                reckon_gateway_http:reply_error(400, <<"invalid_json">>, R0);
            {ok, Body, R} ->
                RawVersion = maps:get(<<"expected_version">>, Body, -2),
                Expected = reckon_gateway_http:parse_expected_version(RawVersion),
                RawEvents = maps:get(<<"events">>, Body, []),
                case parse_proposed(RawEvents) of
                    {error, Reason} ->
                        reckon_gateway_http:reply_error(400, Reason, R);
                    {ok, Events} ->
                        case reckon_gateway_dispatch:call(
                                 append_events,
                                 [StoreId, StreamId, Expected, Events]) of
                            {ok, NewVersion} ->
                                reckon_gateway_http:reply_json(200, #{
                                    <<"version">> => NewVersion,
                                    <<"count">>   => length(Events)
                                }, R);
                            {error, Reason} ->
                                reckon_gateway_http:dispatch_error(Reason, R)
                        end
                end
        end
    end);

%% Read events (forward or backward)
handle(<<"GET">>, events, Req) ->
    StreamId = cowboy_req:binding(stream_id, Req),
    From  = reckon_gateway_http:qs_int(Req, from, 0),
    Limit = reckon_gateway_http:qs_int(Req, limit, 100),
    Dir   = reckon_gateway_http:qs_binary(Req, dir, <<"forward">>),
    Op = case Dir of
        <<"backward">> -> stream_backward;
        _              -> stream_forward
    end,
    with_store(Req, fun(StoreId, R) ->
        case reckon_gateway_dispatch:call(Op, [StoreId, StreamId, From, Limit]) of
            {ok, Events} ->
                reckon_gateway_http:reply_json(200, #{
                    <<"events">> => [reckon_gateway_http:event_to_json_map(E) || E <- Events],
                    <<"count">>  => length(Events)
                }, R);
            {error, Reason} ->
                reckon_gateway_http:dispatch_error(Reason, R)
        end
    end);

%% Stream version
handle(<<"GET">>, version, Req) ->
    StreamId = cowboy_req:binding(stream_id, Req),
    with_store(Req, fun(StoreId, R) ->
        case reckon_gateway_dispatch:call(get_version, [StoreId, StreamId]) of
            {ok, Version}   -> reckon_gateway_http:reply_json(200, #{<<"version">> => Version}, R);
            {error, Reason} -> reckon_gateway_http:dispatch_error(Reason, R)
        end
    end);

%% Read by event types: ?types=a,b,c&limit=N
handle(<<"GET">>, by_type, Req) ->
    Types = reckon_gateway_http:qs_list(Req, types, []),
    Limit = reckon_gateway_http:qs_int(Req, limit, 0),
    with_store(Req, fun(StoreId, R) ->
        case Types of
            [] ->
                reckon_gateway_http:reply_error(400, <<"missing types parameter">>, R);
            _ ->
                case reckon_gateway_dispatch:call(read_by_event_types, [StoreId, Types, Limit]) of
                    {ok, Events} ->
                        reckon_gateway_http:reply_json(200, #{
                            <<"events">> => [reckon_gateway_http:event_to_json_map(E) || E <- Events],
                            <<"count">>  => length(Events)
                        }, R);
                    {error, Reason} ->
                        reckon_gateway_http:dispatch_error(Reason, R)
                end
        end
    end);

%% Read by tags: ?tags=a,b&match=any|all&limit=N
handle(<<"GET">>, by_tags, Req) ->
    Tags  = reckon_gateway_http:qs_list(Req, tags, []),
    Match = reckon_gateway_http:qs_binary(Req, match, <<"any">>),
    Limit = reckon_gateway_http:qs_int(Req, limit, 0),
    MatchAtom = case Match of <<"all">> -> all; _ -> any end,
    with_store(Req, fun(StoreId, R) ->
        case Tags of
            [] ->
                reckon_gateway_http:reply_error(400, <<"missing tags parameter">>, R);
            _ ->
                Opts = #{match => MatchAtom, batch_size => Limit},
                case reckon_gateway_dispatch:call(read_by_tags, [StoreId, Tags, Opts]) of
                    {ok, Events} ->
                        reckon_gateway_http:reply_json(200, #{
                            <<"events">> => [reckon_gateway_http:event_to_json_map(E) || E <- Events],
                            <<"count">>  => length(Events)
                        }, R);
                    {error, Reason} ->
                        reckon_gateway_http:dispatch_error(Reason, R)
                end
        end
    end);

%% Read by metadata: ?key=K&value=V&limit=N
handle(<<"GET">>, by_metadata, Req) ->
    Key   = reckon_gateway_http:qs_binary(Req, key, undefined),
    Value = reckon_gateway_http:qs_binary(Req, value, undefined),
    Limit = reckon_gateway_http:qs_int(Req, limit, 0),
    with_store(Req, fun(StoreId, R) ->
        case {Key, Value} of
            {undefined, _} ->
                reckon_gateway_http:reply_error(400, <<"missing key parameter">>, R);
            {_, undefined} ->
                reckon_gateway_http:reply_error(400, <<"missing value parameter">>, R);
            _ ->
                case reckon_gateway_dispatch:call(read_by_metadata, [StoreId, Key, Value]) of
                    {ok, Events} ->
                        Limited = if Limit > 0 -> lists:sublist(Events, Limit); true -> Events end,
                        reckon_gateway_http:reply_json(200, #{
                            <<"events">> => [reckon_gateway_http:event_to_json_map(E) || E <- Limited],
                            <<"count">>  => length(Limited)
                        }, R);
                    {error, Reason} ->
                        reckon_gateway_http:dispatch_error(Reason, R)
                end
        end
    end);

%% Read global: ?offset=N&limit=N
handle(<<"GET">>, global, Req) ->
    Offset = reckon_gateway_http:qs_int(Req, offset, 0),
    Limit  = reckon_gateway_http:qs_int(Req, limit, 100),
    with_store(Req, fun(StoreId, R) ->
        case reckon_gateway_dispatch:call(read_all_global, [StoreId, Offset, Limit]) of
            {ok, Events} ->
                reckon_gateway_http:reply_json(200, #{
                    <<"events">> => [reckon_gateway_http:event_to_json_map(E) || E <- Events],
                    <<"count">>  => length(Events)
                }, R);
            {error, Reason} ->
                reckon_gateway_http:dispatch_error(Reason, R)
        end
    end);

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
