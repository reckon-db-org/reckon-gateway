%%% @doc gRPC DcbService implementation.
%%%
%%% Translates DCB (Dynamic Consistency Boundary) and CCC (Command
%%% Context Consistency) primitives over to the wire shape declared in
%%% reckon_dcb.proto. Four RPCs:
%%%
%%%   - AppendIfNoTagMatches: conditional-append under the DCB
%%%     pseudo-stream. Server rejects if any event matching the
%%%     request's tag_filter has seq strictly above seq_cutoff.
%%%   - ReadDcbContext: read events matching a TagFilter from the
%%%     DCB pseudo-stream, ordered by seq ascending, with the highest
%%%     seq returned alongside so the caller can use it as a cutoff
%%%     for a follow-up AppendIfNoTagMatches.
%%%   - CccReadByPayload: read events where data[key] == value using
%%%     the store's CCC payload index.
%%%   - CccReadByPayloadHash: read events whose combo-hash of
%%%     data[keys[i]] == values[i] matches the store's CCC hash index.
%%%
%%% The conflict path is a structured Conflict response, NOT a gRPC
%%% error. gRPC status codes stay reserved for transport / backend
%%% errors (UNAVAILABLE, UNIMPLEMENTED, INTERNAL, NOT_FOUND,
%%% INVALID_ARGUMENT).
%%%
%%% Filter algebra is decoded from the recursive oneof in the proto
%%% to the Erlang term shape reckon_gater_types:tag_filter() expects:
%%%
%%%   match_any        -> {any_of,     [Tag]}
%%%   match_all        -> {all_of,     [Tag]}
%%%   event_type_match -> {event_type, binary()}
%%%   conjunction      -> {and_,       [TagFilter]}
%%%   disjunction      -> {or_,        [TagFilter]}
%%%
%%% Per-event semantics for ReadDcbContext mirror
%%% evoq_decision_runtime:match_filter/2 so polyglot consumers see
%%% exactly the same matches the BEAM-side runtime sees.
-module(reckon_gateway_dcb_service).

-behaviour(reckon_gateway_v_1_dcb_service_bhvr).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-export([
    append_if_no_tag_matches/2,
    read_dcb_context/2,
    ccc_read_by_payload/2,
    ccc_read_by_payload_hash/2
]).

-export([
    decode_filter/1,
    collect_tags/1,
    event_matches/2
]).

-define(DCB_STREAM_ID, <<"_dcb">>).
-define(MAX_BATCH_SIZE, 10000).

%%====================================================================
%% AppendIfNoTagMatches
%%====================================================================

append_if_no_tag_matches(#{store_id := StoreIdBin,
                           tag_filter := FilterProto,
                           seq_cutoff := SeqCutoff,
                           events := ProposedEvents}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(append_if_no_tag_matches,
                                       <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case decode_filter(FilterProto) of
                {error, FilterErr} ->
                    reckon_gateway_error:wrap(append_if_no_tag_matches,
                                               <<"3">>, FilterErr);
                {ok, Filter} ->
                    Events = [reckon_gateway_convert:proposed_to_event(
                                E, ?DCB_STREAM_ID)
                              || E <- ProposedEvents],
                    do_append(StoreId, Filter, SeqCutoff, Events, Md)
            end
    end.

do_append(StoreId, Filter, SeqCutoff, Events, Md) ->
    case reckon_gateway_dispatch:call(
           append_if_no_tag_matches,
           [StoreId, Filter, SeqCutoff, Events]) of
        {ok, LastSeq} ->
            Response = #{result => {committed, #{last_seq => LastSeq}}},
            {ok, Response, Md};
        {error, {context_changed, MaxSeq}} ->
            Response = #{result => {conflict, #{max_seq => MaxSeq}}},
            {ok, Response, Md};
        {error, not_supported} ->
            reckon_gateway_error:wrap(append_if_no_tag_matches,
                                       <<"12">>, not_supported);
        {error, no_events} ->
            reckon_gateway_error:wrap(append_if_no_tag_matches,
                                       <<"3">>, no_events);
        {error, store_unknown} ->
            reckon_gateway_error:wrap(append_if_no_tag_matches,
                                       <<"5">>, store_unknown);
        {error, cluster_unavailable} ->
            reckon_gateway_error:wrap(append_if_no_tag_matches,
                                       <<"14">>, cluster_unavailable);
        {error, Reason} ->
            reckon_gateway_error:wrap(append_if_no_tag_matches,
                                       <<"13">>, Reason)
    end.

%%====================================================================
%% ReadDcbContext
%%====================================================================

read_dcb_context(#{store_id := StoreIdBin,
                    tag_filter := FilterProto,
                    batch_size := BatchSize}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(read_dcb_context,
                                       <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case decode_filter(FilterProto) of
                {error, FilterErr} ->
                    reckon_gateway_error:wrap(read_dcb_context,
                                               <<"3">>, FilterErr);
                {ok, Filter} ->
                    do_read(StoreId, Filter, BatchSize, Md)
            end
    end.

do_read(StoreId, Filter, BatchSize, Md) ->
    BS = safe_batch_size(BatchSize),
    AllTags = collect_tags(Filter),
    AllEventTypes = collect_event_types(Filter),
    case {AllTags, AllEventTypes} of
        {[], []} ->
            {ok, #{events => [], max_seq => -1}, Md};
        _ ->
            TagEvents = read_by_tags_or_empty(StoreId, AllTags, BS),
            TypeEvents = read_by_event_types_or_empty(StoreId, AllEventTypes, BS),
            case merge_and_filter(TagEvents, TypeEvents, Filter) of
                {error, Reason} ->
                    map_read_error(read_dcb_context, Reason);
                {ok, Matching} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E)
                                || E <- Matching],
                    MaxSeq = compute_max_seq(Matching),
                    {ok, #{events => Recorded, max_seq => MaxSeq}, Md}
            end
    end.

read_by_tags_or_empty(_StoreId, [], _BS) -> {ok, []};
read_by_tags_or_empty(StoreId, Tags, BS) ->
    Opts = #{match => any, batch_size => BS},
    reckon_gateway_dispatch:call(read_by_tags, [StoreId, Tags, Opts]).

read_by_event_types_or_empty(_StoreId, [], _BS) -> {ok, []};
read_by_event_types_or_empty(StoreId, EventTypes, BS) ->
    reckon_gateway_dispatch:call(read_by_event_types, [StoreId, EventTypes, BS]).

merge_and_filter({error, _} = E, _, _) -> E;
merge_and_filter(_, {error, _} = E, _) -> E;
merge_and_filter({ok, TagEvents}, {ok, TypeEvents}, Filter) ->
    Seen = lists:foldl(
        fun(E, Acc) -> maps:put(dcb_event_key(E), E, Acc) end,
        #{}, TagEvents ++ TypeEvents),
    DcbOnly = [E || E <- maps:values(Seen), is_dcb_event(E)],
    {ok, [E || E <- DcbOnly, event_matches(E, Filter)]}.

map_read_error(Op, store_unknown) ->
    reckon_gateway_error:wrap(Op, <<"5">>, store_unknown);
map_read_error(Op, cluster_unavailable) ->
    reckon_gateway_error:wrap(Op, <<"14">>, cluster_unavailable);
map_read_error(Op, Reason) ->
    reckon_gateway_error:wrap(Op, <<"13">>, Reason).

dcb_event_key(#event{version = V, stream_id = S}) -> {S, V};
dcb_event_key(#{version := V, stream_id := S})    -> {S, V}.

%%====================================================================
%% CccReadByPayload
%%====================================================================

ccc_read_by_payload(#{store_id := StoreIdBin,
                       key      := Key,
                       value    := Value} = Req, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(ccc_read_by_payload,
                                       <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            BS = safe_batch_size(maps:get(batch_size, Req, 0)),
            case reckon_gateway_dispatch:call(
                   ccc_read_by_payload, [StoreId, Key, Value, BS]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E)
                                || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, store_unknown} ->
                    reckon_gateway_error:wrap(ccc_read_by_payload,
                                               <<"5">>, store_unknown);
                {error, cluster_unavailable} ->
                    reckon_gateway_error:wrap(ccc_read_by_payload,
                                               <<"14">>, cluster_unavailable);
                {error, Reason} ->
                    reckon_gateway_error:wrap(ccc_read_by_payload,
                                               <<"13">>, Reason)
            end
    end.

%%====================================================================
%% CccReadByPayloadHash
%%====================================================================

ccc_read_by_payload_hash(#{store_id := StoreIdBin,
                             keys     := Keys,
                             values   := Values} = Req, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(ccc_read_by_payload_hash,
                                       <<"3">>, invalid_store_id);
        {ok, _} when length(Keys) =:= 0 ->
            reckon_gateway_error:wrap(ccc_read_by_payload_hash,
                                       <<"3">>, empty_keys);
        {ok, _} when length(Keys) =/= length(Values) ->
            reckon_gateway_error:wrap(ccc_read_by_payload_hash,
                                       <<"3">>, keys_values_length_mismatch);
        {ok, StoreId} ->
            BS = safe_batch_size(maps:get(batch_size, Req, 0)),
            case reckon_gateway_dispatch:call(
                   ccc_read_by_payload_hash, [StoreId, Keys, Values, BS]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E)
                                || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, store_unknown} ->
                    reckon_gateway_error:wrap(ccc_read_by_payload_hash,
                                               <<"5">>, store_unknown);
                {error, cluster_unavailable} ->
                    reckon_gateway_error:wrap(ccc_read_by_payload_hash,
                                               <<"14">>, cluster_unavailable);
                {error, Reason} ->
                    reckon_gateway_error:wrap(ccc_read_by_payload_hash,
                                               <<"13">>, Reason)
            end
    end.

%%====================================================================
%% TagFilter algebra
%%
%% Public-for-testing. Polyglot consumers see exactly the matches the
%% BEAM-side evoq_decision_runtime sees, so we mirror its per-event
%% semantics here rather than re-derive them.
%%====================================================================

%% @doc Decode a proto TagFilter map into the Erlang term shape used
%% by reckon_gater_types:tag_filter().
-spec decode_filter(map()) -> {ok, term()} | {error, term()}.
decode_filter(#{kind := {match_any, #{tags := Tags}}}) when is_list(Tags) ->
    {ok, {any_of, Tags}};
decode_filter(#{kind := {match_all, #{tags := Tags}}}) when is_list(Tags) ->
    {ok, {all_of, Tags}};
decode_filter(#{kind := {event_type_match, T}}) when is_binary(T), T =/= <<>> ->
    {ok, {event_type, T}};
decode_filter(#{kind := {conjunction, #{filters := Filters}}})
  when is_list(Filters) ->
    decode_subfilters(Filters, and_, []);
decode_filter(#{kind := {disjunction, #{filters := Filters}}})
  when is_list(Filters) ->
    decode_subfilters(Filters, or_, []);
decode_filter(_) ->
    {error, malformed_tag_filter}.

decode_subfilters([], OpAtom, Acc) ->
    {ok, {OpAtom, lists:reverse(Acc)}};
decode_subfilters([Sub | Rest], OpAtom, Acc) ->
    case decode_filter(Sub) of
        {ok, Decoded}    -> decode_subfilters(Rest, OpAtom, [Decoded | Acc]);
        {error, _} = Err -> Err
    end.

%% @doc Set (deduped list) of every tag referenced anywhere in a
%% filter tree.
-spec collect_tags(term()) -> [binary()].
collect_tags({any_of, Tags}) when is_list(Tags) -> lists:usort(Tags);
collect_tags({all_of, Tags}) when is_list(Tags) -> lists:usort(Tags);
collect_tags({event_type, _}) -> [];
collect_tags({and_, Filters}) when is_list(Filters) ->
    lists:usort(lists:flatmap(fun collect_tags/1, Filters));
collect_tags({or_, Filters}) when is_list(Filters) ->
    lists:usort(lists:flatmap(fun collect_tags/1, Filters)).

%% @doc Set (deduped list) of every event_type referenced anywhere
%% in a filter tree.
-spec collect_event_types(term()) -> [binary()].
collect_event_types({any_of, _}) -> [];
collect_event_types({all_of, _}) -> [];
collect_event_types({event_type, T}) when is_binary(T) -> [T];
collect_event_types({and_, Filters}) when is_list(Filters) ->
    lists:usort(lists:flatmap(fun collect_event_types/1, Filters));
collect_event_types({or_, Filters}) when is_list(Filters) ->
    lists:usort(lists:flatmap(fun collect_event_types/1, Filters)).

%% @doc Does an event satisfy the filter? Accepts both
%% #event{} records (as returned by reckon_gater_api:read_by_tags/3)
%% and raw maps (handy for unit testing without a real event).
%%
%% {event_type, T} matches against the event_type field, not tags.
-spec event_matches(#event{} | map() | [binary()], term()) -> boolean().
event_matches(#event{event_type = ET}, {event_type, T}) ->
    ET =:= T;
event_matches(Event, {event_type, T}) when is_map(Event) ->
    maps:get(event_type, Event, maps:get(<<"event_type">>, Event, undefined)) =:= T;
event_matches(_Tags, {event_type, _}) when is_list(_Tags) ->
    false;
event_matches(#event{} = E, {and_, Filters}) ->
    Filters =/= [] andalso lists:all(fun(F) -> event_matches(E, F) end, Filters);
event_matches(#event{} = E, {or_, Filters}) ->
    lists:any(fun(F) -> event_matches(E, F) end, Filters);
event_matches(Event, {and_, Filters}) when is_map(Event) ->
    Filters =/= [] andalso lists:all(fun(F) -> event_matches(Event, F) end, Filters);
event_matches(Event, {or_, Filters}) when is_map(Event) ->
    lists:any(fun(F) -> event_matches(Event, F) end, Filters);
event_matches(#event{tags = Tags}, Filter) ->
    match_tags(normalize_tags(Tags), Filter);
event_matches(Event, Filter) when is_map(Event) ->
    Tags = maps:get(tags, Event, []),
    match_tags(normalize_tags(Tags), Filter);
event_matches(Tags, Filter) when is_list(Tags) ->
    match_tags(Tags, Filter).

normalize_tags(undefined)         -> [];
normalize_tags(L) when is_list(L) -> L.

match_tags(Tags, {any_of, Wanted}) ->
    lists:any(fun(T) -> lists:member(T, Tags) end, Wanted);
match_tags(Tags, {all_of, Wanted}) ->
    Wanted =/= [] andalso
        lists:all(fun(T) -> lists:member(T, Tags) end, Wanted);
match_tags(Tags, {and_, Filters}) ->
    Filters =/= [] andalso
        lists:all(fun(F) -> event_matches(Tags, F) end, Filters);
match_tags(Tags, {or_, Filters}) ->
    lists:any(fun(F) -> event_matches(Tags, F) end, Filters).

%%====================================================================
%% Internal
%%====================================================================

is_dcb_event(#event{stream_id = ?DCB_STREAM_ID}) -> true;
is_dcb_event(#{stream_id := ?DCB_STREAM_ID})     -> true;
is_dcb_event(_)                                  -> false.

event_seq(#event{version = V}) -> V;
event_seq(#{version := V})     -> V.

compute_max_seq([]) -> -1;
compute_max_seq(L)  -> lists:max([event_seq(E) || E <- L]).

safe_batch_size(0)                          -> ?MAX_BATCH_SIZE;
safe_batch_size(N) when N > ?MAX_BATCH_SIZE -> ?MAX_BATCH_SIZE;
safe_batch_size(N)                          -> N.
