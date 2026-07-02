%%% @doc The merged store catalogue across every connected cluster.
%%%
%%% State:
%%%
%%%   catalogue = #{StoreId => ClusterId}    ephemeral; rebuilt per
%%%                                          publish tick.
%%%   clusters  = #{ClusterId => cluster_info()}
%%%
%%% Cluster connectors are the only mutators: each connector calls
%%% `publish/2' on its refresh tick with the cluster's current
%%% `[StoreId]'. The aggregator diffs against the previous tick:
%%% new entries appear, missing ones drop, collisions keep the
%%% existing winner and log once.
%%%
%%% Cookies do not enter or leave this module. The connector holds
%%% them; the catalogue only sees ids.
-module(reckon_gateway_catalogue).
-behaviour(gen_server).

-include("reckon_gateway_telemetry.hrl").

-export([start_link/0, child_spec/0,
         publish/2, remove/1, lookup/1, store_mode/1,
         list_all/0, list_entries/0, status/0,
         subscribe/1, unsubscribe/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-type store_entry() :: #{store_id := atom(), _ => term()}.

-type cluster_info() :: #{members      := [node()],
                          api_module   := atom(),
                          stores       := [store_entry()],
                          status       := up | degraded | unreachable,
                          last_refresh := integer() | undefined}.

-record(state, {
    %% Catalogue map (denormalised view used by lookup/1):
    catalogue = #{} :: #{atom() => atom()},
    %% Per-cluster info:
    clusters  = #{} :: #{atom() => cluster_info()},
    %% Track collisions we've already logged so we don't spam.
    collisions_logged = sets:new() :: sets:set({atom(), atom(), atom()}),
    %% Live-stream subscribers (e.g. WatchStores gRPC handlers).
    %% Map of monitor_ref => pid so we can clean up on subscriber DOWN.
    subscribers = #{} :: #{reference() => pid()}
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec child_spec() -> supervisor:child_spec().
child_spec() ->
    #{id       => ?MODULE,
      start    => {?MODULE, start_link, []},
      restart  => permanent,
      shutdown => 5000,
      type     => worker,
      modules  => [?MODULE]}.

%% @doc Called by a cluster connector after each refresh tick.
%% Replaces the cluster's slice of the catalogue.
-spec publish(atom(),
              #{members      := [node()],
                stores       := [atom()],
                status       := up | degraded | unreachable,
                last_refresh := integer() | undefined}) -> ok.
publish(ClusterId, Info) when is_atom(ClusterId), is_map(Info) ->
    gen_server:cast(?MODULE, {publish, ClusterId, Info}).

%% @doc Called when a cluster is retired (e.g. removed from
%% clusters.eterm at ReloadCatalogue).
-spec remove(atom()) -> ok.
remove(ClusterId) when is_atom(ClusterId) ->
    gen_server:cast(?MODULE, {remove, ClusterId}).

%% @doc Resolve a store_id to its owning cluster, currently-known
%% members, and the api_module that cluster exposes. Used by the
%% dispatch layer.
-spec lookup(atom()) ->
    {ok, atom(), [node()], atom()} | {error, not_found | unreachable}.
lookup(StoreId) when is_atom(StoreId) ->
    gen_server:call(?MODULE, {lookup, StoreId}).

%% @doc Report the mode (single | cluster) of a known store. Used by
%% handlers that need to short-circuit cluster-only RPCs against
%% single-mode reckon-db stores (e.g. HealthService.VerifyClusterConsistency,
%% where the parksim single-mode BEAMs would otherwise spin a retry
%% storm against the missing reckon_db_cluster module).
-spec store_mode(atom()) ->
    {ok, single | cluster} | {error, not_found}.
store_mode(StoreId) when is_atom(StoreId) ->
    gen_server:call(?MODULE, {store_mode, StoreId}).

%% @doc Flat union of every known store. Used by ops scripts.
-spec list_all() -> [{atom(), atom(), atom()}].
list_all() ->
    gen_server:call(?MODULE, list_all).

%% @doc Full registry entries with cluster_id annotated. Used by
%% StoresService.ListStores to populate the proto response without
%% an additional rpc round-trip.
-spec list_entries() -> [#{atom() => term()}].
list_entries() ->
    gen_server:call(?MODULE, list_entries).

%% @doc Full status snapshot used by AdminService.GetCatalogueStatus.
-spec status() ->
    #{catalogue_size := non_neg_integer(),
      clusters       := [map()]}.
status() ->
    gen_server:call(?MODULE, status).

%% @doc Subscribe Pid to live store-event notifications. The
%% catalogue sends `{store_event, announced | retired, Entry}'
%% messages as stores are added or dropped from the merged view.
%% The catalogue monitors the subscriber and cleans up on DOWN.
-spec subscribe(pid()) -> ok.
subscribe(Pid) when is_pid(Pid) ->
    gen_server:cast(?MODULE, {subscribe, Pid}).

%% @doc Idempotent unsubscribe. The catalogue would clean up
%% automatically when the subscriber dies; this is for clients that
%% want to drop the subscription explicitly while staying alive.
-spec unsubscribe(pid()) -> ok.
unsubscribe(Pid) when is_pid(Pid) ->
    gen_server:cast(?MODULE, {unsubscribe, Pid}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    logger:info("[reckon_gateway_catalogue] init"),
    {ok, #state{}}.

handle_call({lookup, StoreId}, _From,
            #state{catalogue = Cat, clusters = CMap} = State) ->
    {reply, lookup_reply(maps:find(StoreId, Cat), CMap), State};

handle_call(list_all, _From,
            #state{catalogue = Cat, clusters = CMap} = State) ->
    Reply = [{StoreId, ClusterId, cluster_status(ClusterId, CMap)}
             || {StoreId, ClusterId} <- maps:to_list(Cat)],
    {reply, Reply, State};

handle_call(list_entries, _From,
            #state{catalogue = Cat, clusters = CMap} = State) ->
    %% Walk catalogue (which holds the winner per store_id after
    %% collision-handling) and annotate each entry with cluster_id.
    Reply = lists:flatten(
        [annotate_owned_entries(StoreId, ClusterId, CMap)
         || {StoreId, ClusterId} <- maps:to_list(Cat)]),
    {reply, Reply, State};

handle_call({store_mode, StoreId}, _From,
            #state{catalogue = Cat, clusters = CMap} = State) ->
    {reply, store_mode_reply(maps:find(StoreId, Cat), StoreId, CMap), State};

handle_call(status, _From,
            #state{catalogue = Cat, clusters = CMap} = State) ->
    Snapshot = #{
        catalogue_size => maps:size(Cat),
        clusters       => [cluster_snapshot(Id, Info) || {Id, Info} <- maps:to_list(CMap)]
    },
    {reply, Snapshot, State};

handle_call(_Msg, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast({publish, ClusterId, Info},
            #state{catalogue = Cat,
                   clusters  = CMap,
                   collisions_logged = LoggedCollisions,
                   subscribers = Subs} = State) ->
    PrevEntries = prev_stores(ClusterId, CMap),
    NewEntries  = maps:get(stores, Info, []),
    PrevIds = entry_ids(PrevEntries),
    NewIds  = entry_ids(NewEntries),
    AddedIds   = NewIds -- PrevIds,
    RemovedIds = PrevIds -- NewIds,
    %% Apply per-store_id add/remove against the denorm catalogue.
    {Cat1, NewLogged, AcceptedAdds} = lists:foldl(
        fun(StoreId, Acc) -> publish_add_step(StoreId, ClusterId, Acc) end,
        {Cat, LoggedCollisions, []}, AddedIds),
    {Cat2, AcceptedRemoves} = lists:foldl(
        fun(StoreId, Acc) -> publish_remove_step(StoreId, ClusterId, Acc) end,
        {Cat1, []}, RemovedIds),
    CMap1 = CMap#{ClusterId => Info},
    case {AddedIds, RemovedIds} of
        {[], []} -> ok;
        _ ->
            logger:info("[reckon_gateway_catalogue ~p] +~p -~p (catalogue size ~b)",
                        [ClusterId, AddedIds, RemovedIds, maps:size(Cat2)])
    end,
    %% Emit live events to subscribers (sub-task 9).
    notify_subscribers(Subs, ClusterId, NewEntries, AcceptedAdds, announced),
    notify_subscribers(Subs, ClusterId, PrevEntries, AcceptedRemoves, retired),
    emit_store_telemetry(AcceptedAdds, ClusterId, announced),
    emit_store_telemetry(AcceptedRemoves, ClusterId, retired),
    {noreply, State#state{catalogue = Cat2,
                          clusters  = CMap1,
                          collisions_logged = NewLogged}};

handle_cast({remove, ClusterId},
            #state{catalogue = Cat, clusters = CMap,
                   subscribers = Subs} = State) ->
    Entries = case maps:get(ClusterId, CMap, undefined) of
        undefined      -> [];
        #{stores := S} -> S
    end,
    OwnedIds = [Id || {Id, C} <- maps:to_list(Cat), C =:= ClusterId],
    Cat1 = maps:filter(fun(_, C) -> C =/= ClusterId end, Cat),
    CMap1 = maps:remove(ClusterId, CMap),
    logger:info("[reckon_gateway_catalogue] removed cluster ~p (was ~b store(s))",
                [ClusterId, length(Entries)]),
    notify_subscribers(Subs, ClusterId, Entries, OwnedIds, retired),
    emit_store_telemetry(OwnedIds, ClusterId, retired),
    {noreply, State#state{catalogue = Cat1, clusters = CMap1}};

handle_cast({subscribe, Pid},
            #state{subscribers = Subs} = State) ->
    Ref = erlang:monitor(process, Pid),
    {noreply, State#state{subscribers = Subs#{Ref => Pid}}};

handle_cast({unsubscribe, Pid},
            #state{subscribers = Subs} = State) ->
    NewSubs = maps:filter(
        fun(Ref, P) when P =:= Pid ->
                erlang:demonitor(Ref, [flush]),
                false;
           (_, _) ->
                true
        end, Subs),
    {noreply, State#state{subscribers = NewSubs}};

handle_cast(_Msg, State) -> {noreply, State}.

handle_info({'DOWN', Ref, process, _Pid, _Reason},
            #state{subscribers = Subs} = State) ->
    {noreply, State#state{subscribers = maps:remove(Ref, Subs)}};
handle_info(_Msg, State) -> {noreply, State}.

%%====================================================================
%% Internals
%%====================================================================

cluster_status(ClusterId, CMap) ->
    case maps:get(ClusterId, CMap, undefined) of
        #{status := S} -> S;
        _              -> unreachable
    end.

prev_stores(ClusterId, CMap) ->
    case maps:get(ClusterId, CMap, undefined) of
        undefined        -> [];
        #{stores := S}   -> S
    end.

entry_ids(Entries) ->
    [maps:get(store_id, E) || E <- Entries].

annotate_owned_entries(StoreId, ClusterId, CMap) ->
    Entries = prev_stores(ClusterId, CMap),
    [E#{cluster_id => ClusterId}
     || E <- Entries, maps:get(store_id, E) =:= StoreId].

%% @private Fire `{store_event, Type, Entry}' to every subscriber for
%% each StoreId that won this publish cycle (collisions already
%% filtered upstream). The Entry is annotated with cluster_id so the
%% WatchStores handler can populate the proto without an additional
%% lookup.
notify_subscribers(_Subs, _ClusterId, _Entries, [], _Type) -> ok;
notify_subscribers(Subs, ClusterId, Entries, AcceptedIds, Type)
  when map_size(Subs) =:= 0 ->
    _ = AcceptedIds, _ = Entries, _ = ClusterId, _ = Type, ok;
notify_subscribers(Subs, ClusterId, Entries, AcceptedIds, Type) ->
    Pids = maps:values(Subs),
    lists:foreach(fun(Id) -> notify_one(Id, Pids, Entries, ClusterId, Type) end, AcceptedIds).

notify_one(Id, Pids, Entries, ClusterId, Type) ->
    notify_match([E || E <- Entries, maps:get(store_id, E) =:= Id], Pids, ClusterId, Type).

%% @private Fire an announced/retired telemetry event per store_id that
%% won this cycle. Runs independently of live subscribers, so metrics
%% flow even when the admin UI / SSE has no one listening.
emit_store_telemetry(StoreIds, ClusterId, Type) ->
    Event = store_event_name(Type),
    lists:foreach(
        fun(StoreId) ->
            telemetry:execute(Event,
                              #{system_time => erlang:system_time(millisecond)},
                              #{store_id => StoreId, cluster_id => ClusterId})
        end, StoreIds).

store_event_name(announced) -> ?GW_STORE_ANNOUNCED;
store_event_name(retired)   -> ?GW_STORE_RETIRED.

notify_match([Entry | _], Pids, ClusterId, Type) ->
    Annotated = Entry#{cluster_id => ClusterId},
    Msg = {store_event, Type, Annotated},
    [P ! Msg || P <- Pids];
notify_match([], _Pids, _ClusterId, _Type) ->
    ok.

cluster_snapshot(Id, #{members := M, stores := S,
                       status  := Status, last_refresh := LR}) ->
    #{cluster_id   => Id,
      members      => M,
      store_count  => length(S),
      status       => Status,
      last_refresh => LR}.

%%====================================================================
%% Catalogue mutation/lookup helpers (flattened out of gen_server
%% callbacks to keep nesting shallow)
%%====================================================================

%% @private lookup reply: resolve store -> cluster -> reachable members.
lookup_reply(error, _CMap) ->
    {error, not_found};
lookup_reply({ok, ClusterId}, CMap) ->
    lookup_cluster(maps:get(ClusterId, CMap, undefined), ClusterId).

lookup_cluster(undefined, _ClusterId) ->
    {error, not_found};
lookup_cluster(#{members := Members, status := Status, api_module := Api}, ClusterId)
  when Status =/= unreachable, Members =/= [] ->
    {ok, ClusterId, Members, Api};
lookup_cluster(_, _ClusterId) ->
    {error, unreachable}.

%% @private store_mode reply: find the store's owning cluster, read the
%% per-entry mode, default to cluster when unset.
store_mode_reply(error, _StoreId, _CMap) ->
    {error, not_found};
store_mode_reply({ok, ClusterId}, StoreId, CMap) ->
    Entries = prev_stores(ClusterId, CMap),
    store_mode_pick([maps:get(mode, E, undefined)
                     || E <- Entries, maps:get(store_id, E) =:= StoreId]).

store_mode_pick([Mode | _]) when Mode =:= single; Mode =:= cluster ->
    {ok, Mode};
store_mode_pick(_) ->
    %% Mode unset on entry (legacy connector, etc.) — fall back to
    %% cluster so we don't silently mis-route consistency checks.
    {ok, cluster}.

%% @private Fold step for added store_ids on publish. First-seen
%% cluster wins; collisions are logged once.
publish_add_step(StoreId, ClusterId, {AccCat, _, _} = Acc) ->
    publish_add_find(maps:find(StoreId, AccCat), StoreId, ClusterId, Acc).

publish_add_find(error, StoreId, ClusterId, {AccCat, AccLogged, AccAccepted}) ->
    {AccCat#{StoreId => ClusterId}, AccLogged, [StoreId | AccAccepted]};
publish_add_find({ok, ClusterId}, _StoreId, ClusterId, Acc) ->
    %% Self-republish; harmless.
    Acc;
publish_add_find({ok, OtherCluster}, StoreId, ClusterId, {AccCat, AccLogged, AccAccepted}) ->
    Key = {StoreId, ClusterId, OtherCluster},
    maybe_log_collision(sets:is_element(Key, AccLogged), StoreId, ClusterId, OtherCluster),
    {AccCat, sets:add_element(Key, AccLogged), AccAccepted}.

maybe_log_collision(true, _StoreId, _ClusterId, _OtherCluster) ->
    ok;
maybe_log_collision(false, StoreId, ClusterId, OtherCluster) ->
    logger:warning("[reckon_gateway_catalogue] store_id ~p offered by both ~p and ~p;"
                   " first-seen (~p) wins",
                   [StoreId, ClusterId, OtherCluster, OtherCluster]).

%% @private Fold step for removed store_ids on publish. Only drop the
%% entry if this cluster still owns it.
publish_remove_step(StoreId, ClusterId, {AccCat, _} = Acc) ->
    publish_remove_find(maps:find(StoreId, AccCat), StoreId, ClusterId, Acc).

publish_remove_find({ok, ClusterId}, StoreId, ClusterId, {AccCat, AccAccepted}) ->
    {maps:remove(StoreId, AccCat), [StoreId | AccAccepted]};
publish_remove_find(_, _StoreId, _ClusterId, Acc) ->
    %% owned by someone else now
    Acc.
