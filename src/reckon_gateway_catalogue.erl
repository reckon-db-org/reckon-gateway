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

-export([start_link/0, child_spec/0,
         publish/2, remove/1, lookup/1, list_all/0, list_entries/0, status/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-type store_entry() :: #{store_id := atom(), _ => term()}.

-type cluster_info() :: #{members      := [node()],
                          stores       := [store_entry()],
                          status       := up | degraded | unreachable,
                          last_refresh := integer() | undefined}.

-record(state, {
    %% Catalogue map (denormalised view used by lookup/1):
    catalogue = #{} :: #{atom() => atom()},
    %% Per-cluster info:
    clusters  = #{} :: #{atom() => cluster_info()},
    %% Track collisions we've already logged so we don't spam.
    collisions_logged = sets:new() :: sets:set({atom(), atom(), atom()})
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

%% @doc Resolve a store_id to its owning cluster + currently-known
%% members. Used by the dispatch layer.
-spec lookup(atom()) ->
    {ok, atom(), [node()]} | {error, not_found | unreachable}.
lookup(StoreId) when is_atom(StoreId) ->
    gen_server:call(?MODULE, {lookup, StoreId}).

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

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    logger:info("[reckon_gateway_catalogue] init"),
    {ok, #state{}}.

handle_call({lookup, StoreId}, _From,
            #state{catalogue = Cat, clusters = CMap} = State) ->
    Reply = case maps:find(StoreId, Cat) of
        error ->
            {error, not_found};
        {ok, ClusterId} ->
            case maps:get(ClusterId, CMap, undefined) of
                undefined ->
                    {error, not_found};
                #{members := Members, status := Status} when Status =/= unreachable, Members =/= [] ->
                    {ok, ClusterId, Members};
                _ ->
                    {error, unreachable}
            end
    end,
    {reply, Reply, State};

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
                   collisions_logged = LoggedCollisions} = State) ->
    PrevIds = entry_ids(prev_stores(ClusterId, CMap)),
    NewIds  = entry_ids(maps:get(stores, Info, [])),
    Added   = NewIds -- PrevIds,
    Removed = PrevIds -- NewIds,
    %% Apply per-store_id add/remove against the denorm catalogue.
    {Cat1, NewLogged} = lists:foldl(
        fun(StoreId, {AccCat, AccLogged}) ->
            case maps:find(StoreId, AccCat) of
                error ->
                    {AccCat#{StoreId => ClusterId}, AccLogged};
                {ok, ClusterId} ->
                    %% Self-republish; harmless.
                    {AccCat, AccLogged};
                {ok, OtherCluster} ->
                    Key = {StoreId, ClusterId, OtherCluster},
                    case sets:is_element(Key, AccLogged) of
                        true -> ok;
                        false ->
                            logger:warning("[reckon_gateway_catalogue] store_id ~p"
                                           " offered by both ~p and ~p; first-seen"
                                           " (~p) wins",
                                           [StoreId, ClusterId, OtherCluster,
                                            OtherCluster])
                    end,
                    {AccCat, sets:add_element(Key, AccLogged)}
            end
        end, {Cat, LoggedCollisions}, Added),
    Cat2 = lists:foldl(
        fun(StoreId, AccCat) ->
            case maps:find(StoreId, AccCat) of
                {ok, ClusterId} -> maps:remove(StoreId, AccCat);
                _               -> AccCat       %% owned by someone else now
            end
        end, Cat1, Removed),
    CMap1 = CMap#{ClusterId => Info},
    case {Added, Removed} of
        {[], []} -> ok;
        _ ->
            logger:info("[reckon_gateway_catalogue ~p] +~p -~p (catalogue size ~b)",
                        [ClusterId, Added, Removed, maps:size(Cat2)])
    end,
    {noreply, State#state{catalogue = Cat2,
                          clusters  = CMap1,
                          collisions_logged = NewLogged}};

handle_cast({remove, ClusterId},
            #state{catalogue = Cat, clusters = CMap} = State) ->
    Stores = case maps:get(ClusterId, CMap, undefined) of
        undefined      -> [];
        #{stores := S} -> S
    end,
    Cat1 = maps:filter(fun(_, C) -> C =/= ClusterId end, Cat),
    CMap1 = maps:remove(ClusterId, CMap),
    logger:info("[reckon_gateway_catalogue] removed cluster ~p (was ~b store(s))",
                [ClusterId, length(Stores)]),
    {noreply, State#state{catalogue = Cat1, clusters = CMap1}};

handle_cast(_Msg, State) -> {noreply, State}.

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

cluster_snapshot(Id, #{members := M, stores := S,
                       status  := Status, last_refresh := LR}) ->
    #{cluster_id   => Id,
      members      => M,
      store_count  => length(S),
      status       => Status,
      last_refresh => LR}.
