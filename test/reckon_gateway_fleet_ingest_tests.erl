%%% @doc Rate-derivation tests for reckon_gateway_fleet_ingest.
%%%
%%% The live poller needs real stores, so these exercise the pure
%%% sample→rate math directly via the TEST-only surface.
-module(reckon_gateway_fleet_ingest_tests).

-include_lib("eunit/include/eunit.hrl").

-define(M, reckon_gateway_fleet_ingest).

%% First sample establishes a baseline; no prior count → rate 0.
first_sample_has_zero_rate_test() ->
    S = ?M:apply_sample([{leuven, {ok, 100}}, {ghent, {ok, 50}}], 1000,
                        ?M:initial_state()),
    Snap = ?M:build_snapshot(S),
    ?assertEqual(150, maps:get(<<"total_events">>, Snap)),
    ?assertEqual(0.0, maps:get(<<"events_per_s">>, Snap)).

%% Second sample diffs against the first: 10 new events over 1s = 10/s;
%% a store with no new events reports 0/s.
delta_becomes_rate_test() ->
    S1 = ?M:apply_sample([{leuven, {ok, 100}}, {ghent, {ok, 50}}], 1000,
                         ?M:initial_state()),
    S2 = ?M:apply_sample([{leuven, {ok, 110}}, {ghent, {ok, 50}}], 2000, S1),
    Snap = ?M:build_snapshot(S2),
    ?assertEqual(160, maps:get(<<"total_events">>, Snap)),
    ?assertEqual(10.0, maps:get(<<"events_per_s">>, Snap)),
    Leuven = find_store(<<"leuven">>, Snap),
    ?assertEqual(10.0, maps:get(<<"per_s">>, Leuven)),
    Ghent = find_store(<<"ghent">>, Snap),
    ?assertEqual(0.0, maps:get(<<"per_s">>, Ghent)).

%% Elapsed time scales the rate: 20 events over 2s = 10/s.
rate_is_per_second_test() ->
    S1 = ?M:apply_sample([{leuven, {ok, 100}}], 1000, ?M:initial_state()),
    S2 = ?M:apply_sample([{leuven, {ok, 120}}], 3000, S1),
    Snap = ?M:build_snapshot(S2),
    ?assertEqual(10.0, maps:get(<<"events_per_s">>, Snap)).

%% A shrinking count (scavenge/prune) never yields a negative rate.
scavenge_yields_zero_not_negative_test() ->
    S1 = ?M:apply_sample([{leuven, {ok, 100}}], 1000, ?M:initial_state()),
    S2 = ?M:apply_sample([{leuven, {ok, 80}}], 2000, S1),
    Snap = ?M:build_snapshot(S2),
    ?assertEqual(0.0, maps:get(<<"events_per_s">>, Snap)),
    ?assertEqual(80, maps:get(<<"total_events">>, Snap)).

%% An unreachable store keeps its last count (no flicker) and reports 0/s.
unreachable_store_carries_count_test() ->
    S1 = ?M:apply_sample([{leuven, {ok, 100}}, {ghent, {ok, 50}}], 1000,
                         ?M:initial_state()),
    S2 = ?M:apply_sample([{leuven, {ok, 110}}, {ghent, error}], 2000, S1),
    Snap = ?M:build_snapshot(S2),
    ?assertEqual(160, maps:get(<<"total_events">>, Snap)),
    Ghent = find_store(<<"ghent">>, Snap),
    ?assertEqual(50, maps:get(<<"events">>, Ghent)),
    ?assertEqual(0.0, maps:get(<<"per_s">>, Ghent)).

%% After an unreachable tick, the next successful read diffs against the
%% pre-failure baseline (carried prev), not a reset.
recovery_diffs_against_carried_baseline_test() ->
    S1 = ?M:apply_sample([{ghent, {ok, 50}}], 1000, ?M:initial_state()),
    S2 = ?M:apply_sample([{ghent, error}],    2000, S1),
    S3 = ?M:apply_sample([{ghent, {ok, 70}}], 3000, S2),
    Snap = ?M:build_snapshot(S3),
    %% 70 - 50 = 20 events over 2s (1000→3000) = 10/s.
    ?assertEqual(10.0, maps:get(<<"events_per_s">>, Snap)).

find_store(Name, Snap) ->
    [S] = [S || S <- maps:get(<<"per_store">>, Snap),
                maps:get(<<"store_id">>, S) =:= Name],
    S.
