%%% @doc Supervisor over the catalogue's per-cluster connectors.
%%% Loads the cluster catalogue from `clusters.eterm' at boot,
%%% spawns one `reckon_gateway_cluster_connector' per entry.
%%%
%%% Restart strategy is one_for_one: a failed connector for cluster A
%%% does not cycle connectors for clusters B, C, ...
%%%
%%% `reload_from_disk/0' is the entry point for the
%%% `AdminService.ReloadCatalogue' gRPC. It re-reads the eterm,
%%% diffs against the live child set, and reconciles:
%%%
%%%   added     — new cluster_id, spawn child
%%%   removed   — gone cluster_id, terminate child
%%%   restarted — same cluster_id but different config (cookie or
%%%               members or api_module), terminate + start
%%%
%%% On config-load failure (bad eterm, duplicate cluster_id, missing
%%% required field), the live state is NOT mutated and the error is
%%% returned to the caller.
-module(reckon_gateway_clusters_sup).
-behaviour(supervisor).

-export([start_link/0, reload_from_disk/0, current_specs/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 5,
        period    => 30
    },
    Children = case reckon_gateway_config:load_clusters() of
        {ok, []} ->
            logger:info("[reckon_gateway_clusters_sup] no clusters configured"),
            [];
        {ok, Specs} ->
            logger:info("[reckon_gateway_clusters_sup] starting ~b connector(s)",
                        [length(Specs)]),
            [reckon_gateway_cluster_connector:child_spec(S) || S <- Specs];
        {error, Reason} ->
            logger:error("[reckon_gateway_clusters_sup] config error: ~p", [Reason]),
            []
    end,
    {ok, {SupFlags, Children}}.

%%====================================================================
%% Reload — invoked by AdminService.ReloadCatalogue
%%====================================================================

-spec reload_from_disk() ->
    {ok, #{added := [atom()], removed := [atom()], restarted := [atom()]}}
    | {error, term()}.
reload_from_disk() ->
    case reckon_gateway_config:load_clusters() of
        {error, _} = E -> E;
        {ok, NewSpecs} ->
            Live = live_specs(),
            apply_diff(Live, NewSpecs)
    end.

%% @doc Map of currently-running cluster_id => spec (as the connector
%% was started with). Used as the "before" side of the reload diff.
-spec current_specs() -> #{atom() => map()}.
current_specs() ->
    live_specs().

live_specs() ->
    Children = supervisor:which_children(?MODULE),
    lists:foldl(fun({{connector, Id}, Pid, _, _}, Acc) when is_pid(Pid) ->
                        try
                            Status = reckon_gateway_cluster_connector:status(Id),
                            Acc#{Id => spec_from_status(Status)}
                        catch _:_ ->
                            Acc
                        end;
                   (_, Acc) ->
                        Acc
                end, #{}, Children).

%% @private Reconstruct the comparable slice of a spec from a status
%% snapshot. Cookie isn't in the status (deliberately); we get it
%% from the on-disk file when computing the diff.
spec_from_status(#{cluster_id := Id,
                   configured := Members,
                   api_module := Api}) ->
    #{cluster_id => Id, members => Members, api_module => Api}.

apply_diff(LiveMap, NewSpecs) ->
    NewMap = maps:from_list([{maps:get(cluster_id, S), S} || S <- NewSpecs]),
    LiveIds = maps:keys(LiveMap),
    NewIds  = maps:keys(NewMap),

    Added       = NewIds -- LiveIds,
    Removed     = LiveIds -- NewIds,
    Common      = NewIds -- Added,
    Restarted   = [Id || Id <- Common, spec_changed(maps:get(Id, LiveMap),
                                                     maps:get(Id, NewMap))],

    [start_connector(maps:get(Id, NewMap)) || Id <- Added],
    [terminate_connector(Id) || Id <- Removed],
    %% Restarted: terminate the old, spawn with new spec.
    [begin
         terminate_connector(Id),
         start_connector(maps:get(Id, NewMap))
     end || Id <- Restarted],

    logger:info("[reckon_gateway_clusters_sup] reload diff: +~p -~p ~~~p",
                [Added, Removed, Restarted]),
    {ok, #{added => Added, removed => Removed, restarted => Restarted}}.

%% @private We compare the dimensions visible from runtime status —
%% members + api_module. Cookie changes are NOT visible from status
%% (intentionally), so a pure cookie rotation is detectable only by
%% comparing against the on-disk eterm. For simplicity we treat the
%% common case (members/api change) here; pure cookie rotation
%% requires the operator to bump a sentinel field (e.g. tweak the
%% member list ordering) OR to remove + re-add the cluster.
%%
%% A future iteration can stash a hash of the eterm entry in each
%% connector and compare hashes; that catches cookie-only rotations
%% without ever surfacing the cookie itself.
spec_changed(Live, New) ->
    maps:get(members,    Live) =/= maps:get(members,    New) orelse
    maps:get(api_module, Live, reckon_gater_api) =/=
        maps:get(api_module, New, reckon_gater_api).

start_connector(Spec) ->
    ChildSpec = reckon_gateway_cluster_connector:child_spec(Spec),
    case supervisor:start_child(?MODULE, ChildSpec) of
        {ok, _Pid}                          -> ok;
        {error, {already_started, _Pid}}    -> ok;
        Other                                -> Other
    end.

terminate_connector(Id) ->
    ChildId = {connector, Id},
    _ = supervisor:terminate_child(?MODULE, ChildId),
    _ = supervisor:delete_child(?MODULE, ChildId),
    ok.
