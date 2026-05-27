%%% @doc gRPC DcbService implementation.
%%%
%%% Translates the DCB (Dynamic Consistency Boundary) primitive shipped
%%% in reckon-db 3.1.1+ over to the wire shape declared in
%%% reckon_dcb.proto. Two RPCs:
%%%
%%%   - AppendIfNoTagMatches: conditional-append under the DCB
%%%     pseudo-stream. Server rejects if any event matching the
%%%     request's tag_filter has seq strictly above seq_cutoff.
%%%   - ReadDcbContext: read events matching a TagFilter from the
%%%     DCB pseudo-stream, ordered by seq ascending, with the highest
%%%     seq returned alongside so the caller can use it as a cutoff
%%%     for a follow-up AppendIfNoTagMatches.
%%%
%%% The conflict path is a structured Conflict response, NOT a gRPC
%%% error. gRPC status codes stay reserved for transport / backend
%%% errors (UNAVAILABLE, UNIMPLEMENTED, INTERNAL, NOT_FOUND,
%%% INVALID_ARGUMENT).
%%%
%%% Filter algebra is decoded from the recursive oneof in the proto
%%% to the Erlang term shape reckon_gater_types:tag_filter() expects:
%%%
%%%   match_any   -> {any_of,  [Tag]}
%%%   match_all   -> {all_of,  [Tag]}
%%%   conjunction -> {and_,    [TagFilter]}
%%%   disjunction -> {or_,     [TagFilter]}
%%%
%%% Per-event semantics for ReadDcbContext mirror
%%% evoq_decision_runtime:match_filter/2 so polyglot consumers see
%%% exactly the same matches the BEAM-side runtime sees.
-module(reckon_gateway_dcb_service).

-behaviour(reckon_gateway_v_1_dcb_service_bhvr).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-export([
    append_if_no_tag_matches/2,
    read_dcb_context/2
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
    case collect_tags(Filter) of
        [] ->
            %% Vacuous compound filter, e.g., {or_, []}. No tags to
            %% read; no events qualify.
            {ok, #{events => [], max_seq => -1}, Md};
        Tags ->
            Opts = #{match => any, batch_size => BS},
            case reckon_gateway_dispatch:call(read_by_tags,
                                              [StoreId, Tags, Opts]) of
                {ok, Events} ->
                    DcbOnly = [E || E <- Events, is_dcb_event(E)],
                    Matching = [E || E <- DcbOnly,
                                     event_matches(E, Filter)],
                    Recorded = [reckon_gateway_convert:event_to_recorded(E)
                                || E <- Matching],
                    MaxSeq = compute_max_seq(Matching),
                    {ok, #{events => Recorded, max_seq => MaxSeq}, Md};
                {error, store_unknown} ->
                    reckon_gateway_error:wrap(read_dcb_context,
                                               <<"5">>, store_unknown);
                {error, cluster_unavailable} ->
                    reckon_gateway_error:wrap(read_dcb_context,
                                               <<"14">>, cluster_unavailable);
                {error, Reason} ->
                    reckon_gateway_error:wrap(read_dcb_context,
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
%% filter tree. Used to compute the broadest tag-superset for
%% read_by_tags before client-side refinement.
-spec collect_tags(term()) -> [binary()].
collect_tags({any_of, Tags}) when is_list(Tags) -> lists:usort(Tags);
collect_tags({all_of, Tags}) when is_list(Tags) -> lists:usort(Tags);
collect_tags({and_, Filters}) when is_list(Filters) ->
    lists:usort(lists:flatmap(fun collect_tags/1, Filters));
collect_tags({or_, Filters}) when is_list(Filters) ->
    lists:usort(lists:flatmap(fun collect_tags/1, Filters)).

%% @doc Does an event's tag set satisfy the filter? Accepts both
%% #event{} records (as returned by reckon_gater_api:read_by_tags/3)
%% and raw maps (handy for unit testing without a real event).
-spec event_matches(#event{} | map() | [binary()], term()) -> boolean().
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
        lists:all(fun(F) -> match_tags(Tags, F) end, Filters);
match_tags(Tags, {or_, Filters}) ->
    lists:any(fun(F) -> match_tags(Tags, F) end, Filters).

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
