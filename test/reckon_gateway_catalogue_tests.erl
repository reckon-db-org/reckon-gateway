%%% @doc Unit tests for the catalogue aggregator. Drives publish/2
%%% directly so we don't need real clusters or dist connections.
%%% Verifies:
%%%   - merge across two clusters
%%%   - lookup distinguishes by cluster
%%%   - removed entries drop from the catalogue
%%%   - first-seen-wins on duplicate store_id
%%%   - remove/1 drops a cluster's slice cleanly
-module(reckon_gateway_catalogue_tests).

-include_lib("eunit/include/eunit.hrl").

setup() ->
    %% Each test gets its own catalogue process - cleaner than
    %% sharing state.
    case whereis(reckon_gateway_catalogue) of
        undefined -> ok;
        OldPid    ->
            unlink_and_stop(OldPid)
    end,
    {ok, Pid} = reckon_gateway_catalogue:start_link(),
    Pid.

cleanup(Pid) ->
    unlink_and_stop(Pid).

unlink_and_stop(Pid) ->
    try
        unlink(Pid),
        Ref = monitor(process, Pid),
        exit(Pid, shutdown),
        receive {'DOWN', Ref, process, Pid, _} -> ok
        after 1000 -> ok
        end
    catch _:_ -> ok
    end.

%%====================================================================
%% Helpers
%%====================================================================

entry(StoreId, Node) ->
    #{store_id      => StoreId,
      node          => Node,
      mode          => single,
      data_dir      => "/tmp/" ++ atom_to_list(StoreId),
      timeout       => 5000,
      registered_at => erlang:system_time(millisecond)}.

publish(ClusterId, Members, Stores) ->
    reckon_gateway_catalogue:publish(ClusterId, #{
        members      => Members,
        api_module   => reckon_gater_api,
        stores       => Stores,
        status       => up,
        last_refresh => erlang:system_time(millisecond)
    }),
    %% publish is a cast; round-trip a call to make sure the cast was processed.
    _ = reckon_gateway_catalogue:list_all(),
    ok.

%%====================================================================
%% Tests
%%====================================================================

catalogue_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [
        fun empty_at_startup/1,
        fun single_cluster_publish/1,
        fun two_clusters_merge/1,
        fun lookup_returns_owning_cluster/1,
        fun lookup_returns_api_module/1,
        fun lookup_unknown_returns_not_found/1,
        fun republish_replaces_stores/1,
        fun collision_first_seen_wins/1,
        fun remove_drops_cluster_slice/1,
        fun unreachable_status_makes_lookup_unreachable/1,
        fun subscriber_receives_announced/1,
        fun subscriber_receives_retired_on_diff/1,
        fun subscriber_receives_retired_on_cluster_remove/1,
        fun unsubscribe_stops_events/1,
        fun subscriber_pruned_on_death/1,
        fun store_mode_single/1,
        fun store_mode_unknown/1,
        fun store_mode_defaults_to_cluster_on_missing_field/1
     ]}.

empty_at_startup(_) ->
    [?_assertEqual([], reckon_gateway_catalogue:list_all()),
     ?_assertEqual(0, maps:get(catalogue_size,
                               reckon_gateway_catalogue:status()))].

single_cluster_publish(_) ->
    fun() ->
        publish(parksim, ['p1@h'],
                [entry(parksim_entry2exit_store, 'p1@h')]),
        [{StoreId, ClusterId, Status}] = reckon_gateway_catalogue:list_all(),
        ?assertEqual(parksim_entry2exit_store, StoreId),
        ?assertEqual(parksim,                  ClusterId),
        ?assertEqual(up,                       Status)
    end.

two_clusters_merge(_) ->
    fun() ->
        publish(parksim, ['p1@h'],
                [entry(parksim_entry2exit_store, 'p1@h')]),
        publish(marketplace, ['m1@h'],
                [entry(marketplace_main_store, 'm1@h'),
                 entry(marketplace_offers_store, 'm1@h')]),
        All = lists:sort(reckon_gateway_catalogue:list_all()),
        ?assertEqual(3, length(All)),
        StoreIds = [Id || {Id, _, _} <- All],
        ?assert(lists:member(parksim_entry2exit_store, StoreIds)),
        ?assert(lists:member(marketplace_main_store,   StoreIds)),
        ?assert(lists:member(marketplace_offers_store, StoreIds))
    end.

lookup_returns_owning_cluster(_) ->
    fun() ->
        publish(parksim, ['p1@h', 'p2@h'],
                [entry(parksim_entry2exit_store, 'p1@h')]),
        publish(marketplace, ['m1@h'],
                [entry(marketplace_main_store, 'm1@h')]),
        {ok, Cluster, Members, _Api} =
            reckon_gateway_catalogue:lookup(parksim_entry2exit_store),
        ?assertEqual(parksim, Cluster),
        ?assertEqual(['p1@h', 'p2@h'], Members),
        {ok, MCluster, _, _} =
            reckon_gateway_catalogue:lookup(marketplace_main_store),
        ?assertEqual(marketplace, MCluster)
    end.

lookup_returns_api_module(_) ->
    fun() ->
        reckon_gateway_catalogue:publish(legacy, #{
            members      => ['l1@h'],
            api_module   => esdb_gater_api,
            stores       => [entry(legacy_store, 'l1@h')],
            status       => up,
            last_refresh => erlang:system_time(millisecond)
        }),
        _ = reckon_gateway_catalogue:list_all(),  %% sync
        {ok, _, _, Api} = reckon_gateway_catalogue:lookup(legacy_store),
        ?assertEqual(esdb_gater_api, Api)
    end.

lookup_unknown_returns_not_found(_) ->
    fun() ->
        ?assertEqual({error, not_found},
                     reckon_gateway_catalogue:lookup(no_such_store))
    end.

republish_replaces_stores(_) ->
    fun() ->
        publish(parksim, ['p1@h'],
                [entry(a_store, 'p1@h'),
                 entry(b_store, 'p1@h')]),
        ?assertEqual(2, length(reckon_gateway_catalogue:list_all())),
        %% Tick 2: a_store retired, c_store added.
        publish(parksim, ['p1@h'],
                [entry(b_store, 'p1@h'),
                 entry(c_store, 'p1@h')]),
        Ids = lists:sort([Id || {Id, _, _} <- reckon_gateway_catalogue:list_all()]),
        ?assertEqual([b_store, c_store], Ids)
    end.

collision_first_seen_wins(_) ->
    fun() ->
        publish(cluster_a, ['a@h'],
                [entry(shared_store, 'a@h')]),
        publish(cluster_b, ['b@h'],
                [entry(shared_store, 'b@h')]),
        {ok, Owner, _, _} =
            reckon_gateway_catalogue:lookup(shared_store),
        ?assertEqual(cluster_a, Owner),
        ?assertEqual(1, length(reckon_gateway_catalogue:list_all()))
    end.

remove_drops_cluster_slice(_) ->
    fun() ->
        publish(parksim, ['p@h'],
                [entry(parksim_store, 'p@h')]),
        publish(marketplace, ['m@h'],
                [entry(marketplace_store, 'm@h')]),
        ?assertEqual(2, length(reckon_gateway_catalogue:list_all())),
        reckon_gateway_catalogue:remove(parksim),
        _ = reckon_gateway_catalogue:list_all(),  %% sync the cast
        [{Surviving, marketplace, _}] = reckon_gateway_catalogue:list_all(),
        ?assertEqual(marketplace_store, Surviving),
        ?assertEqual({error, not_found},
                     reckon_gateway_catalogue:lookup(parksim_store))
    end.

unreachable_status_makes_lookup_unreachable(_) ->
    fun() ->
        publish(parksim, ['p@h'],
                [entry(parksim_store, 'p@h')]),
        %% Now publish the same store under an unreachable status —
        %% the catalogue still has the entry but lookup should
        %% reflect that the cluster is down.
        reckon_gateway_catalogue:publish(parksim, #{
            members      => [],
            api_module   => reckon_gater_api,
            stores       => [entry(parksim_store, 'p@h')],
            status       => unreachable,
            last_refresh => erlang:system_time(millisecond)
        }),
        _ = reckon_gateway_catalogue:list_all(),  %% sync
        ?assertEqual({error, unreachable},
                     reckon_gateway_catalogue:lookup(parksim_store))
    end.

subscriber_receives_announced(_) ->
    fun() ->
        reckon_gateway_catalogue:subscribe(self()),
        _ = reckon_gateway_catalogue:list_all(),  %% sync the cast
        publish(parksim, ['p@h'], [entry(parksim_store, 'p@h')]),
        receive
            {store_event, announced, #{store_id := parksim_store,
                                        cluster_id := parksim}} -> ok
        after 1000 ->
            ?assert(false)
        end
    end.

subscriber_receives_retired_on_diff(_) ->
    fun() ->
        publish(parksim, ['p@h'],
                [entry(a, 'p@h'), entry(b, 'p@h')]),
        reckon_gateway_catalogue:subscribe(self()),
        _ = reckon_gateway_catalogue:list_all(),
        %% Tick 2: a retired, b survives.
        publish(parksim, ['p@h'], [entry(b, 'p@h')]),
        receive
            {store_event, retired, #{store_id := a,
                                      cluster_id := parksim}} -> ok
        after 1000 ->
            ?assert(false)
        end
    end.

subscriber_receives_retired_on_cluster_remove(_) ->
    fun() ->
        publish(parksim, ['p@h'], [entry(only_store, 'p@h')]),
        reckon_gateway_catalogue:subscribe(self()),
        _ = reckon_gateway_catalogue:list_all(),
        reckon_gateway_catalogue:remove(parksim),
        receive
            {store_event, retired, #{store_id := only_store}} -> ok
        after 1000 ->
            ?assert(false)
        end
    end.

unsubscribe_stops_events(_) ->
    fun() ->
        reckon_gateway_catalogue:subscribe(self()),
        _ = reckon_gateway_catalogue:list_all(),
        reckon_gateway_catalogue:unsubscribe(self()),
        _ = reckon_gateway_catalogue:list_all(),  %% sync the unsubscribe cast
        publish(parksim, ['p@h'], [entry(should_not_arrive, 'p@h')]),
        receive
            {store_event, _, _} = E ->
                ?assertEqual(no_event_after_unsub, {got, E})
        after 200 ->
            ok
        end
    end.

subscriber_pruned_on_death(_) ->
    fun() ->
        Parent = self(),
        %% Spawn a doomed subscriber. After it exits, the catalogue's
        %% monitor fires; nothing should crash the catalogue.
        Doomed = spawn(fun() ->
            reckon_gateway_catalogue:subscribe(self()),
            Parent ! subscribed,
            receive die -> ok end
        end),
        receive subscribed -> ok after 1000 -> ?assert(false) end,
        _ = reckon_gateway_catalogue:list_all(),  %% sync subscribe
        Doomed ! die,
        %% Give the catalogue a moment to process DOWN.
        timer:sleep(50),
        %% The catalogue must still be alive + responsive.
        ?assertEqual([], reckon_gateway_catalogue:list_all())
    end.

%%====================================================================
%% store_mode/1 — drives HealthService.VerifyClusterConsistency
%% single-mode short-circuit.
%%====================================================================

store_mode_single(_) ->
    fun() ->
        publish(parksim, ['p@h'], [entry(parksim_entry2exit_store, 'p@h')]),
        ?assertEqual({ok, single},
                     reckon_gateway_catalogue:store_mode(parksim_entry2exit_store))
    end.

store_mode_unknown(_) ->
    fun() ->
        ?assertEqual({error, not_found},
                     reckon_gateway_catalogue:store_mode(no_such_store))
    end.

store_mode_defaults_to_cluster_on_missing_field(_) ->
    fun() ->
        %% Legacy connector or hand-built entry without the `mode' key.
        %% Conservative default: cluster, so Raft consistency RPCs are
        %% NOT silently skipped on a real cluster.
        BareEntry = #{store_id      => legacy_store,
                      node          => 'l@h',
                      data_dir      => "/tmp/legacy_store",
                      timeout       => 5000,
                      registered_at => erlang:system_time(millisecond)},
        reckon_gateway_catalogue:publish(legacy, #{
            members      => ['l@h'],
            api_module   => esdb_gater_api,
            stores       => [BareEntry],
            status       => up,
            last_refresh => erlang:system_time(millisecond)
        }),
        _ = reckon_gateway_catalogue:list_all(),  %% sync the cast
        ?assertEqual({ok, cluster},
                     reckon_gateway_catalogue:store_mode(legacy_store))
    end.
