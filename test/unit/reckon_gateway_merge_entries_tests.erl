%%% @doc Unit tests for reckon_gateway_cluster_connector:merge_entries/1.
%%%
%%% A cluster-mode store runs on N replica nodes, so unioning each
%%% member's local registry yields one entry per (store_id, node). The
%%% catalogue needs exactly one entry per store_id (its add/remove diff
%%% is keyed by store_id occurrence), enriched with the full replica set
%%% so the admin UI can show every node + mark the leader. These tests
%%% pin that collapse-and-enrich behaviour.
-module(reckon_gateway_merge_entries_tests).

-include_lib("eunit/include/eunit.hrl").

entry(StoreId, Node) ->
    #{store_id => StoreId, node => Node, mode => cluster,
      data_dir => "/d", timeout => 5000, registered_at => 1}.

%% Three replicas of one store collapse to a single entry carrying all
%% three nodes (sorted, unique) and replica_count = 3.
three_replicas_collapse_to_one_test() ->
    In = [entry(leuven, 'p@a'), entry(leuven, 'p@b'), entry(leuven, 'p@c')],
    [Out] = reckon_gateway_cluster_connector:merge_entries(In),
    ?assertEqual(leuven, maps:get(store_id, Out)),
    ?assertEqual(['p@a', 'p@b', 'p@c'], maps:get(nodes, Out)),
    ?assertEqual(3, maps:get(replica_count, Out)).

%% The kept entry is the first-seen one; original fields survive.
first_seen_entry_is_kept_test() ->
    In = [entry(leuven, 'p@a'), entry(leuven, 'p@b')],
    [Out] = reckon_gateway_cluster_connector:merge_entries(In),
    ?assertEqual('p@a', maps:get(node, Out)),
    ?assertEqual("/d", maps:get(data_dir, Out)),
    ?assertEqual(cluster, maps:get(mode, Out)).

%% nodes is sorted + de-duplicated even when input order/dupes vary.
nodes_are_sorted_and_unique_test() ->
    In = [entry(x, 'p@c'), entry(x, 'p@a'), entry(x, 'p@c'), entry(x, 'p@b')],
    [Out] = reckon_gateway_cluster_connector:merge_entries(In),
    ?assertEqual(['p@a', 'p@b', 'p@c'], maps:get(nodes, Out)),
    ?assertEqual(3, maps:get(replica_count, Out)).

%% Multiple stores each keep their own replica set; store order is
%% first-seen across the flattened input.
multiple_stores_preserve_first_seen_order_test() ->
    In = [entry(leuven, 'p@a'), entry(ghent, 'p@a'),
          entry(leuven, 'p@b'), entry(ghent, 'p@c')],
    Out = reckon_gateway_cluster_connector:merge_entries(In),
    ?assertEqual([leuven, ghent], [maps:get(store_id, E) || E <- Out]),
    [L, G] = Out,
    ?assertEqual(['p@a', 'p@b'], maps:get(nodes, L)),
    ?assertEqual(['p@a', 'p@c'], maps:get(nodes, G)).

%% A single-replica store still gets nodes + replica_count = 1.
single_replica_gets_singleton_nodes_test() ->
    [Out] = reckon_gateway_cluster_connector:merge_entries([entry(solo, 'p@a')]),
    ?assertEqual(['p@a'], maps:get(nodes, Out)),
    ?assertEqual(1, maps:get(replica_count, Out)).

empty_input_yields_empty_test() ->
    ?assertEqual([], reckon_gateway_cluster_connector:merge_entries([])).
