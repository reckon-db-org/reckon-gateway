%%% @doc Unit tests for the DcbService filter algebra.
%%%
%%% The handler module composes three pure functions:
%%%
%%%   - decode_filter/1:  proto TagFilter map  -> Erlang term
%%%   - collect_tags/1:   filter term         -> deduped tag list
%%%   - event_matches/2:  event + filter      -> boolean
%%%
%%% These compose into the read/decide/write Decision loop without
%%% touching reckon_db; tests here exercise the algebra against fixed
%%% data so polyglot wire-shape regressions show up before the CT
%%% suite needs to spin up a cluster.
-module(reckon_gateway_dcb_service_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-define(M, reckon_gateway_dcb_service).

%%====================================================================
%% decode_filter/1
%%====================================================================

decode_match_any_test() ->
    Proto = #{kind => {match_any,
                       #{tags => [<<"a">>, <<"b">>]}}},
    ?assertEqual({ok, {any_of, [<<"a">>, <<"b">>]}},
                 ?M:decode_filter(Proto)).

decode_match_all_test() ->
    Proto = #{kind => {match_all,
                       #{tags => [<<"x">>]}}},
    ?assertEqual({ok, {all_of, [<<"x">>]}},
                 ?M:decode_filter(Proto)).

decode_conjunction_test() ->
    Proto = #{kind => {conjunction,
                       #{filters => [
                           #{kind => {match_any, #{tags => [<<"r">>]}}},
                           #{kind => {match_all, #{tags => [<<"g">>]}}}
                       ]}}},
    ?assertEqual({ok, {and_, [{any_of, [<<"r">>]},
                              {all_of, [<<"g">>]}]}},
                 ?M:decode_filter(Proto)).

decode_disjunction_test() ->
    Proto = #{kind => {disjunction,
                       #{filters => [
                           #{kind => {match_all, #{tags => [<<"u">>]}}},
                           #{kind => {match_any, #{tags => [<<"v">>]}}}
                       ]}}},
    ?assertEqual({ok, {or_, [{all_of, [<<"u">>]},
                             {any_of, [<<"v">>]}]}},
                 ?M:decode_filter(Proto)).

decode_nested_compound_test() ->
    %% {or_, [{and_, [match_any [a], match_all [b]]}, match_any [c]]}
    Proto = #{kind => {disjunction,
                       #{filters => [
                           #{kind => {conjunction,
                                      #{filters => [
                                          #{kind => {match_any, #{tags => [<<"a">>]}}},
                                          #{kind => {match_all, #{tags => [<<"b">>]}}}
                                      ]}}},
                           #{kind => {match_any, #{tags => [<<"c">>]}}}
                       ]}}},
    Expected = {or_, [{and_, [{any_of, [<<"a">>]},
                              {all_of, [<<"b">>]}]},
                      {any_of, [<<"c">>]}]},
    ?assertEqual({ok, Expected}, ?M:decode_filter(Proto)).

decode_malformed_test() ->
    ?assertEqual({error, malformed_tag_filter},
                 ?M:decode_filter(#{})),
    ?assertEqual({error, malformed_tag_filter},
                 ?M:decode_filter(#{kind => {unknown, #{}}})),
    ?assertEqual({error, malformed_tag_filter},
                 ?M:decode_filter(not_a_map)).

decode_malformed_in_subtree_test() ->
    %% Conjunction with one well-formed and one malformed sub-filter:
    %% propagates the inner error rather than wrapping silently.
    Proto = #{kind => {conjunction,
                       #{filters => [
                           #{kind => {match_any, #{tags => [<<"ok">>]}}},
                           #{kind => garbage}
                       ]}}},
    ?assertEqual({error, malformed_tag_filter},
                 ?M:decode_filter(Proto)).

%%====================================================================
%% collect_tags/1
%%====================================================================

collect_tags_leaf_test() ->
    ?assertEqual([<<"a">>, <<"b">>],
                 ?M:collect_tags({any_of, [<<"a">>, <<"b">>]})),
    ?assertEqual([<<"x">>],
                 ?M:collect_tags({all_of, [<<"x">>]})).

collect_tags_leaf_dedupes_test() ->
    ?assertEqual([<<"a">>, <<"b">>],
                 ?M:collect_tags({any_of, [<<"a">>, <<"b">>, <<"a">>]})).

collect_tags_compound_unions_test() ->
    Filter = {or_, [{any_of, [<<"a">>, <<"b">>]},
                    {all_of, [<<"b">>, <<"c">>]}]},
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>],
                 ?M:collect_tags(Filter)).

collect_tags_nested_compound_test() ->
    Filter = {and_, [{or_, [{any_of, [<<"a">>]},
                            {all_of, [<<"b">>, <<"d">>]}]},
                     {any_of, [<<"c">>, <<"a">>]}]},
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>, <<"d">>],
                 ?M:collect_tags(Filter)).

%%====================================================================
%% event_matches/2 — raw tag list
%%====================================================================

match_any_of_any_present_test() ->
    ?assertEqual(true,
                 ?M:event_matches([<<"x">>, <<"a">>],
                                   {any_of, [<<"a">>, <<"b">>]})).

match_any_of_none_present_test() ->
    ?assertEqual(false,
                 ?M:event_matches([<<"x">>, <<"y">>],
                                   {any_of, [<<"a">>, <<"b">>]})).

match_all_of_all_present_test() ->
    ?assertEqual(true,
                 ?M:event_matches([<<"a">>, <<"b">>, <<"c">>],
                                   {all_of, [<<"a">>, <<"b">>]})).

match_all_of_one_missing_test() ->
    ?assertEqual(false,
                 ?M:event_matches([<<"a">>, <<"c">>],
                                   {all_of, [<<"a">>, <<"b">>]})).

match_all_of_empty_wanted_is_false_test() ->
    %% {all_of, []} is vacuous; treat as 'no constraint'? Convention:
    %% match_tags returns false to avoid accidental match-everything
    %% queries from misencoded wire input. Mirrors evoq_decision_runtime.
    ?assertEqual(false,
                 ?M:event_matches([<<"a">>], {all_of, []})).

match_compound_and_test() ->
    Filter = {and_, [{any_of, [<<"a">>]},
                     {all_of, [<<"b">>, <<"c">>]}]},
    ?assertEqual(true,
                 ?M:event_matches([<<"a">>, <<"b">>, <<"c">>], Filter)),
    ?assertEqual(false,
                 ?M:event_matches([<<"a">>, <<"b">>], Filter)),
    ?assertEqual(false,
                 ?M:event_matches([<<"b">>, <<"c">>], Filter)).

match_compound_or_test() ->
    Filter = {or_, [{all_of, [<<"a">>, <<"b">>]},
                    {any_of, [<<"x">>]}]},
    ?assertEqual(true,
                 ?M:event_matches([<<"a">>, <<"b">>], Filter)),
    ?assertEqual(true,
                 ?M:event_matches([<<"x">>], Filter)),
    ?assertEqual(false,
                 ?M:event_matches([<<"a">>], Filter)).

match_compound_and_empty_is_false_test() ->
    ?assertEqual(false,
                 ?M:event_matches([<<"a">>], {and_, []})).

match_compound_or_empty_is_false_test() ->
    ?assertEqual(false,
                 ?M:event_matches([<<"a">>], {or_, []})).

%%====================================================================
%% event_matches/2 — event records and maps
%%====================================================================

match_event_record_test() ->
    E = #event{event_id = <<"id-1">>,
               event_type = <<"reserved">>,
               stream_id = <<"_dcb">>,
               version = 7,
               data = #{},
               metadata = #{},
               tags = [<<"slot:42">>]},
    ?assertEqual(true,
                 ?M:event_matches(E, {any_of, [<<"slot:42">>]})),
    ?assertEqual(false,
                 ?M:event_matches(E, {any_of, [<<"slot:99">>]})).

match_event_record_undefined_tags_test() ->
    %% Reckon-db records may carry tags = undefined when the producer
    %% didn't set any. Treat as "no tags".
    E = #event{event_id = <<"id-2">>,
               event_type = <<"sentinel">>,
               stream_id = <<"_dcb">>,
               version = 0,
               data = #{},
               metadata = #{},
               tags = undefined},
    ?assertEqual(false,
                 ?M:event_matches(E, {any_of, [<<"x">>]})).

match_event_map_test() ->
    Evt = #{event_id => <<"id-3">>, tags => [<<"r">>, <<"g">>]},
    ?assertEqual(true,
                 ?M:event_matches(Evt, {all_of, [<<"r">>]})),
    ?assertEqual(false,
                 ?M:event_matches(Evt, {all_of, [<<"b">>]})).

%%====================================================================
%% Wire-shape end-to-end: decode + collect + match
%%====================================================================

%% Polyglot wire-shape: a client sends a proto TagFilter, the gateway
%% decodes it, computes the tag-superset, calls read_by_tags, then
%% client-side refines via event_matches. This test walks that full
%% pipeline on fixtures.
end_to_end_decision_test() ->
    Proto = #{kind => {disjunction,
                       #{filters => [
                           #{kind => {match_all, #{tags => [<<"a">>, <<"b">>]}}},
                           #{kind => {match_any, #{tags => [<<"c">>]}}}
                       ]}}},
    {ok, Filter} = ?M:decode_filter(Proto),
    %% Superset for read_by_tags:
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>],
                 ?M:collect_tags(Filter)),
    %% Per-event refinement:
    ?assertEqual(true,
                 ?M:event_matches([<<"a">>, <<"b">>], Filter)),
    ?assertEqual(true,
                 ?M:event_matches([<<"c">>, <<"z">>], Filter)),
    ?assertEqual(false,
                 ?M:event_matches([<<"a">>], Filter)),
    ?assertEqual(false,
                 ?M:event_matches([<<"x">>, <<"y">>], Filter)).
