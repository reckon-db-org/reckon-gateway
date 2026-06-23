%%% @doc HTTP/JSON handlers for DcbService operations.
%%%
%%% Routes (under /v1/stores/:store_id/):
%%%
%%%   POST /dcb/context         ReadDcbContext
%%%   POST /dcb/append          AppendIfNoTagMatches
%%%   GET  /dcb/log             Paginated DCB event log
%%%   GET  /dcb/tags            Tag index with event counts
%%%   GET  /dcb/event-types     Event type index with event counts
%%%
%%% Request body uses the JSON TagFilter algebra:
%%%   {"match_any": [...]}  {"match_all": [...]}  {"event_type": "..."}
%%%   {"and": [...]}        {"or": [...]}
-module(reckon_gateway_http_dcb).

-behaviour(cowboy_handler).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-export([init/2]).

-define(DCB_STREAM_ID, <<"_dcb">>).
-define(MAX_BATCH, 10000).

init(Req0, #{op := Op} = State) ->
    Req = handle(cowboy_req:method(Req0), Op, Req0),
    {ok, Req, State}.

handle(<<"OPTIONS">>, _Op, Req) ->
    reckon_gateway_http:cors_preflight(Req);

%% POST /dcb/context
%% Body: {"tag_filter": {...}, "batch_size": N}
%% Response: {"events": [...], "max_seq": N}
handle(<<"POST">>, context, Req0) ->
    with_store(Req0, fun(StoreId, R0) ->
        case reckon_gateway_http:read_json_body(R0) of
            {error, invalid_json} ->
                reckon_gateway_http:reply_error(400, <<"invalid_json">>, R0);
            {ok, Body, R} ->
                FilterRaw = maps:get(<<"tag_filter">>, Body, undefined),
                BatchSize = maps:get(<<"batch_size">>, Body, 0),
                with_filter(FilterRaw, R, fun(Filter) ->
                    do_context(StoreId, Filter, BatchSize, R)
                end)
        end
    end);

%% POST /dcb/append
%% Body: {"tag_filter": {...}, "seq_cutoff": N, "events": [...]}
%% Response: {"committed": {"last_seq": N}} or {"conflict": {"max_seq": N}}
handle(<<"POST">>, append, Req0) ->
    with_store(Req0, fun(StoreId, R0) ->
        case reckon_gateway_http:read_json_body(R0) of
            {error, invalid_json} ->
                reckon_gateway_http:reply_error(400, <<"invalid_json">>, R0);
            {ok, Body, R} ->
                FilterRaw = maps:get(<<"tag_filter">>, Body, undefined),
                SeqCutoff = maps:get(<<"seq_cutoff">>, Body, -1),
                RawEvents = maps:get(<<"events">>, Body, []),
                with_filter(FilterRaw, R, fun(Filter) ->
                    case parse_proposed(RawEvents, R) of
                        {error, Req1} -> Req1;
                        {ok, Events}  ->
                            do_append(StoreId, Filter, SeqCutoff, Events, R)
                    end
                end)
        end
    end);

%% GET /dcb/log?from=0&limit=50
%% Response: {"events": [...], "total_count": N, "from_seq": N, "limit": N}
handle(<<"GET">>, log, Req0) ->
    with_store(Req0, fun(StoreId, R) ->
        FromSeq = reckon_gateway_http:qs_int(R, <<"from">>, 0),
        Limit   = min(reckon_gateway_http:qs_int(R, <<"limit">>, 50), 200),
        case reckon_gateway_dispatch:call(dcb_read_log, [StoreId, FromSeq, Limit]) of
            {ok, #{events := Events, total_count := TotalCount}} ->
                reckon_gateway_http:reply_json(200, #{
                    <<"events">>      => [reckon_gateway_http:event_to_json_map(E) || E <- Events],
                    <<"total_count">> => TotalCount,
                    <<"from_seq">>    => FromSeq,
                    <<"limit">>       => Limit
                }, R);
            {error, Reason} ->
                reckon_gateway_http:dispatch_error(Reason, R)
        end
    end);

%% GET /dcb/tags
%% Response: {"tags": [{"tag": "...", "count": N}, ...]}
handle(<<"GET">>, tags, Req0) ->
    with_store(Req0, fun(StoreId, R) ->
        case reckon_gateway_dispatch:call(dcb_all_tags, [StoreId]) of
            {ok, Tags} ->
                reckon_gateway_http:reply_json(200, #{
                    <<"tags">> => [#{<<"tag">> => T, <<"count">> => C} || {T, C} <- Tags]
                }, R);
            {error, Reason} ->
                reckon_gateway_http:dispatch_error(Reason, R)
        end
    end);

%% GET /dcb/event-types
%% Response: {"event_types": [{"event_type": "...", "count": N}, ...]}
handle(<<"GET">>, event_types, Req0) ->
    with_store(Req0, fun(StoreId, R) ->
        case reckon_gateway_dispatch:call(dcb_all_event_types, [StoreId]) of
            {ok, Types} ->
                reckon_gateway_http:reply_json(200, #{
                    <<"event_types">> => [#{<<"event_type">> => T, <<"count">> => C} || {T, C} <- Types]
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

with_filter(undefined, Req, _Fun) ->
    reckon_gateway_http:reply_error(400, <<"missing tag_filter">>, Req);
with_filter(FilterRaw, Req, Fun) ->
    case reckon_gateway_http:decode_filter(FilterRaw) of
        {error, _}   -> reckon_gateway_http:reply_error(400, <<"malformed_tag_filter">>, Req);
        {ok, Filter} -> Fun(Filter)
    end.

parse_proposed(RawEvents, Req) when is_list(RawEvents) ->
    lists:foldl(fun
        (_, {error, _} = E) -> E;
        (E, {ok, Acc}) ->
            case reckon_gateway_http:proposed_from_json(E) of
                {error, Reason} ->
                    {error, reckon_gateway_http:reply_error(400, Reason, Req)};
                Map ->
                    {ok, [Map | Acc]}
            end
    end, {ok, []}, RawEvents);
parse_proposed(_, Req) ->
    {error, reckon_gateway_http:reply_error(400, <<"events must be an array">>, Req)}.

%% Mirrors reckon_gateway_dcb_service:do_read/4 — fetches by tags AND
%% by event_types, deduplicates, filters against the full predicate,
%% and returns only DCB-stream events.
do_context(StoreId, Filter, BatchSize, Req) ->
    BS = safe_batch(BatchSize),
    AllTags       = reckon_gateway_dcb_service:collect_tags(Filter),
    AllEventTypes = collect_event_types(Filter),
    case {AllTags, AllEventTypes} of
        {[], []} ->
            reckon_gateway_http:reply_json(200,
                #{<<"events">> => [], <<"max_seq">> => -1}, Req);
        _ ->
            TagResult  = fetch_by_tags(StoreId, AllTags, BS),
            TypeResult = fetch_by_types(StoreId, AllEventTypes, BS),
            case {TagResult, TypeResult} of
                {{error, Reason}, _} ->
                    reckon_gateway_http:dispatch_error(Reason, Req);
                {_, {error, Reason}} ->
                    reckon_gateway_http:dispatch_error(Reason, Req);
                {{ok, TagEvs}, {ok, TypeEvs}} ->
                    Merged = merge_and_filter(TagEvs, TypeEvs, Filter),
                    MaxSeq = max_seq(Merged),
                    reckon_gateway_http:reply_json(200, #{
                        <<"events">>  => [reckon_gateway_http:event_to_json_map(E) || E <- Merged],
                        <<"max_seq">> => MaxSeq
                    }, Req)
            end
    end.

fetch_by_tags(_StoreId, [], _BS) -> {ok, []};
fetch_by_tags(StoreId, Tags, BS) ->
    reckon_gateway_dispatch:call(read_by_tags,
        [StoreId, Tags, #{match => any, batch_size => BS}]).

fetch_by_types(_StoreId, [], _BS) -> {ok, []};
fetch_by_types(StoreId, Types, BS) ->
    reckon_gateway_dispatch:call(read_by_event_types, [StoreId, Types, BS]).

merge_and_filter(TagEvs, TypeEvs, Filter) ->
    Seen = lists:foldl(
        fun(E, Acc) -> maps:put(event_key(E), E, Acc) end,
        #{}, TagEvs ++ TypeEvs),
    [E || E <- maps:values(Seen),
          is_dcb(E),
          reckon_gateway_dcb_service:event_matches(E, Filter)].

do_append(StoreId, Filter, SeqCutoff, Events, Req) ->
    case reckon_gateway_dispatch:call(
             append_if_no_tag_matches,
             [StoreId, Filter, SeqCutoff, Events]) of
        {ok, LastSeq} ->
            reckon_gateway_http:reply_json(200,
                #{<<"committed">> => #{<<"last_seq">> => LastSeq}}, Req);
        {error, {context_changed, MaxSeq}} ->
            reckon_gateway_http:reply_json(200,
                #{<<"conflict">> => #{<<"max_seq">> => MaxSeq}}, Req);
        {error, not_supported} ->
            reckon_gateway_http:reply_error(501, not_supported, Req);
        {error, no_events} ->
            reckon_gateway_http:reply_error(400, no_events, Req);
        {error, Reason} ->
            reckon_gateway_http:dispatch_error(Reason, Req)
    end.

%% Mirrors reckon_gateway_dcb_service:collect_event_types/1
collect_event_types({event_type, T}) when is_binary(T) -> [T];
collect_event_types({any_of, _})                       -> [];
collect_event_types({all_of, _})                       -> [];
collect_event_types({and_, Fs}) when is_list(Fs) ->
    lists:usort(lists:flatmap(fun collect_event_types/1, Fs));
collect_event_types({or_, Fs}) when is_list(Fs) ->
    lists:usort(lists:flatmap(fun collect_event_types/1, Fs)).

is_dcb(#event{stream_id = ?DCB_STREAM_ID}) -> true;
is_dcb(#{stream_id := ?DCB_STREAM_ID})     -> true;
is_dcb(_)                                  -> false.

event_key(#event{stream_id = S, version = V}) -> {S, V};
event_key(#{stream_id := S, version := V})    -> {S, V}.

max_seq([])  -> -1;
max_seq(Evs) -> lists:max([seq(E) || E <- Evs]).

seq(#event{version = V}) -> V;
seq(#{version := V})     -> V.

safe_batch(0) -> ?MAX_BATCH;
safe_batch(N) when N > ?MAX_BATCH -> ?MAX_BATCH;
safe_batch(N) -> N.
