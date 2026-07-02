%%% @doc One gen_server per configured cluster. Owns the Erlang dist
%%% connections to the cluster's members and refreshes membership +
%%% (in sub-task 4) the store list periodically.
%%%
%%% Lifecycle:
%%%
%%%   init/1            -> store config, schedule {continue, connect}
%%%   handle_continue   -> set per-peer cookie, connect to every
%%%                        configured member, monitor each, arm
%%%                        refresh timer.
%%%   handle_info(refresh) -> reconnect to any missing configured
%%%                           members + (sub-task 4) re-publish
%%%                           stores.
%%%   handle_info({nodedown, N}) -> drop N from connected members;
%%%                                 next refresh tick will try to
%%%                                 reconnect.
%%%
%%% Registered name: reckon_gateway_cluster_(id).
%%%
%%% Cookie is held in process state; never logged or returned.
-module(reckon_gateway_cluster_connector).
-behaviour(gen_server).

-export([start_link/1, child_spec/1, name/1, status/1]).
-export([init/1, handle_continue/2, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-ifdef(TEST).
-export([merge_entries/1]).
-endif.

-record(state, {
    cluster_id     :: atom(),
    configured     :: [node()],                %% from clusters.eterm
    cookie         :: atom(),                  %% per-peer cookie
    api_module     :: atom(),                  %% e.g. reckon_gater_api | esdb_gater_api
    members        :: [node()],                %% currently connected
    status         :: not_yet_connected | up | unreachable | degraded,
    last_refresh   :: integer() | undefined,
    last_error     :: term() | undefined,
    refresh_ms     :: pos_integer(),
    refresh_timer  :: reference() | undefined
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link(reckon_gateway_config:cluster_spec()) ->
    {ok, pid()} | {error, term()}.
start_link(#{cluster_id := Id} = Spec) ->
    gen_server:start_link({local, name(Id)}, ?MODULE, Spec, []).

-spec child_spec(reckon_gateway_config:cluster_spec()) ->
    supervisor:child_spec().
child_spec(#{cluster_id := Id} = Spec) ->
    #{id       => {connector, Id},
      start    => {?MODULE, start_link, [Spec]},
      restart  => permanent,
      shutdown => 5000,
      type     => worker,
      modules  => [?MODULE]}.

-spec name(atom()) -> atom().
name(Id) when is_atom(Id) ->
    list_to_atom("reckon_gateway_cluster_" ++ atom_to_list(Id)).

%% @doc Snapshot for ops + the (forthcoming) GetCatalogueStatus admin
%% RPC. Cookie is deliberately omitted.
-spec status(atom()) -> #{atom() => term()}.
status(Id) ->
    gen_server:call(name(Id), get_status).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init(#{cluster_id := Id, members := Configured, cookie := CookieBin} = Spec) ->
    Cookie = binary_to_atom(CookieBin, utf8),
    ApiModule = maps:get(api_module, Spec, reckon_gater_api),
    RefreshMs = application:get_env(reckon_gateway, refresh_interval_ms, 30_000),
    logger:info("[reckon_gateway_cluster ~p] init members=~p cookie=<~b bytes> "
                "api=~p refresh=~bms",
                [Id, Configured, byte_size(CookieBin), ApiModule, RefreshMs]),
    State = #state{
        cluster_id    = Id,
        configured    = Configured,
        cookie        = Cookie,
        api_module    = ApiModule,
        members       = [],
        status        = not_yet_connected,
        refresh_ms    = RefreshMs
    },
    {ok, State, {continue, connect}}.

handle_continue(connect, State) ->
    {noreply, do_connect(State)}.

handle_call(get_status, _From, #state{cluster_id = Id,
                                       configured = Configured,
                                       api_module = ApiModule,
                                       members    = Members,
                                       status     = Status,
                                       last_refresh = LR,
                                       last_error = LE} = State) ->
    Reply = #{
        cluster_id    => Id,
        configured    => Configured,
        api_module    => ApiModule,
        members       => Members,
        status        => Status,
        last_refresh  => LR,
        last_error    => LE
    },
    {reply, Reply, State};
handle_call(_Msg, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast(_Msg, State) -> {noreply, State}.

handle_info(refresh, State) ->
    {noreply, refresh(State)};
handle_info({nodedown, Node}, #state{cluster_id = Id,
                                      configured = Configured,
                                      members    = Members} = State) ->
    NewMembers = lists:delete(Node, Members),
    Targets = [N || N <- Configured, N =/= node()],
    logger:warning("[reckon_gateway_cluster ~p] nodedown ~p (~b/~b connected)",
                   [Id, Node, length(NewMembers), length(Targets)]),
    %% Next refresh tick reconnects.
    {noreply, State#state{members = NewMembers,
                          status  = classify(NewMembers, Targets),
                          last_error = {nodedown, Node}}};
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(Reason, #state{cluster_id = Id, members = Members}) ->
    logger:info("[reckon_gateway_cluster ~p] terminating: ~p (members=~b)",
                [Id, Reason, length(Members)]),
    %% Drop our slice of the catalogue so list_all stops showing
    %% stores from a retired cluster.
    catch reckon_gateway_catalogue:remove(Id),
    %% Be explicit — don't leave dangling monitors at shutdown.
    [erlang:monitor_node(N, false) || N <- Members],
    ok.

%%====================================================================
%% Internals
%%====================================================================

%% @doc Connect to every configured member of the cluster, with the
%% per-peer cookie. Each connect_node attempt is independent — a
%% failed connect to one member does not block the others.
do_connect(#state{cluster_id = Id,
                  configured = Configured,
                  cookie     = Cookie,
                  api_module = ApiModule,
                  refresh_ms = RefreshMs} = State) ->
    Self = node(),
    Targets = [N || N <- Configured, N =/= Self],
    Connected = lists:filter(fun(N) -> connect_one(N, Cookie) end, Targets),
    [erlang:monitor_node(M, true) || M <- Connected],
    Timer = erlang:send_after(RefreshMs, self(), refresh),
    Status = classify(Connected, Targets),
    logger:info("[reckon_gateway_cluster ~p] connected ~b/~b: ~p (status=~p)",
                [Id, length(Connected), length(Targets), Connected, Status]),
    Now = erlang:system_time(millisecond),
    Stores = discover_stores(Id, Connected),
    publish_catalogue(Id, Connected, ApiModule, Stores, Status, Now),
    State#state{members      = Connected,
                status       = Status,
                last_refresh = Now,
                last_error   = case Status of
                                   up         -> undefined;
                                   degraded   -> {partial, Targets -- Connected};
                                   unreachable -> {all_unreachable, Targets}
                               end,
                refresh_timer = Timer}.

classify(Connected, Targets) when length(Connected) =:= length(Targets) -> up;
classify([], _Targets) -> unreachable;
classify(_Some, _Targets) -> degraded.

%% Use net_kernel:connect_node/1 (explicit) rather than
%% net_adm:ping/1. They behave the same under default dist settings,
%% but if the operator ever sets dist_auto_connect to `never`, ping
%% breaks (its gen:call to the peer goes through implicit-connect-
%% via-send, which `never` suppresses). connect_node is the
%% supported path under both modes.
connect_one(Node, Cookie) ->
    erlang:set_cookie(Node, Cookie),
    case net_kernel:connect_node(Node) of
        true ->
            true;
        false ->
            logger:warning("[reckon_gateway_cluster] connect_node ~p failed (cookie or unreachable)", [Node]),
            false;
        ignored ->
            logger:warning("[reckon_gateway_cluster] connect_node ~p ignored (local dist not started)", [Node]),
            false
    end.

%% @doc Refresh tick: reconnect to any configured member we lost,
%% update status, reschedule.
refresh(#state{cluster_id = Id,
               configured = Configured,
               members    = Members,
               cookie     = Cookie,
               api_module = ApiModule,
               refresh_ms = RefreshMs} = State) ->
    Self = node(),
    Targets = [N || N <- Configured, N =/= Self],
    Missing = Targets -- Members,
    Reconnected = lists:filter(fun(N) -> connect_one(N, Cookie) end, Missing),
    [erlang:monitor_node(M, true) || M <- Reconnected],
    case Reconnected of
        [] -> ok;
        _  -> logger:info("[reckon_gateway_cluster ~p] refresh reconnected ~p", [Id, Reconnected])
    end,
    NewMembers = Members ++ Reconnected,
    Status = classify(NewMembers, Targets),
    Timer = erlang:send_after(RefreshMs, self(), refresh),
    Now = erlang:system_time(millisecond),
    Stores = discover_stores(Id, NewMembers),
    publish_catalogue(Id, NewMembers, ApiModule, Stores, Status, Now),
    State#state{members       = NewMembers,
                status        = Status,
                last_refresh  = Now,
                refresh_timer = Timer}.

%% @doc Union the live store registry entries across every connected
%% member. Returns a list of registry-entry maps:
%%
%%   #{store_id := atom(), node := node(), mode := atom(),
%%     data_dir := string(), timeout := pos_integer(),
%%     registered_at := integer()}
%%
%% A cluster-mode store runs on N replica nodes (parksim: 3), so
%% `list_stores' from each member yields one entry per node for the
%% same store_id. `merge_entries' collapses those to ONE entry per
%% store_id (first-seen wins) while folding every replica's node into
%% a `nodes' list + `replica_count', so the admin UI can show the
%% replica set while the catalogue keeps a single entry per store_id.
discover_stores(ClusterId, Members) ->
    All = lists:flatten([discover_one(ClusterId, M) || M <- Members]),
    merge_entries(All).

discover_one(ClusterId, Member) ->
    case rpc:call(Member, reckon_db_store_registry, list_stores, []) of
        {ok, Entries} when is_list(Entries) ->
            [E || E <- Entries, is_map(E), maps:is_key(store_id, E)];
        {badrpc, Why} ->
            logger:warning("[reckon_gateway_cluster ~p] list_stores via ~p failed: ~p",
                           [ClusterId, Member, Why]),
            [];
        Other ->
            logger:warning("[reckon_gateway_cluster ~p] list_stores via ~p returned unexpected shape: ~p",
                           [ClusterId, Member, Other]),
            []
    end.

%% @private Collapse per-node registry entries to one entry per
%% store_id (first-seen wins), enriched with the full replica set:
%% `nodes' (sorted, unique) + `replica_count'. Keeping a single entry
%% per store_id is required — the catalogue's add/remove diff is keyed
%% by store_id occurrence, so duplicates would make a lost replica look
%% like a dropped store.
merge_entries(Entries) ->
    Ids     = ordered_unique_ids(Entries),
    NodeMap = lists:foldl(fun collect_nodes/2, #{}, Entries),
    FirstMap = lists:foldl(fun collect_first/2, #{}, Entries),
    [attach_replicas(maps:get(Id, FirstMap), maps:get(Id, NodeMap)) || Id <- Ids].

ordered_unique_ids(Entries) ->
    lists:reverse(lists:foldl(fun order_step/2, [], Entries)).

order_step(#{store_id := Id}, Acc) ->
    prepend_new(lists:member(Id, Acc), Id, Acc).

prepend_new(true, _Id, Acc)  -> Acc;
prepend_new(false, Id, Acc)  -> [Id | Acc].

collect_nodes(#{store_id := Id, node := Node}, Acc) ->
    Acc#{Id => lists:usort([Node | maps:get(Id, Acc, [])])}.

collect_first(#{store_id := Id} = E, Acc) ->
    keep_first(maps:is_key(Id, Acc), Id, E, Acc).

keep_first(true, _Id, _E, Acc) -> Acc;
keep_first(false, Id, E, Acc)  -> Acc#{Id => E}.

attach_replicas(Entry, Nodes) ->
    Entry#{nodes => Nodes, replica_count => length(Nodes)}.

publish_catalogue(ClusterId, Members, ApiModule, Stores, Status, Now) ->
    reckon_gateway_catalogue:publish(ClusterId, #{
        members      => Members,
        api_module   => ApiModule,
        stores       => Stores,
        status       => Status,
        last_refresh => Now
    }).

