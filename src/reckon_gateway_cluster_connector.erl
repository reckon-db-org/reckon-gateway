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
%%% Registered name: `reckon_gateway_cluster_<id>`.
%%%
%%% Cookie is held in process state; never logged or returned.
-module(reckon_gateway_cluster_connector).
-behaviour(gen_server).

-export([start_link/1, child_spec/1, name/1, status/1]).
-export([init/1, handle_continue/2, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-record(state, {
    cluster_id     :: atom(),
    configured     :: [node()],                %% from clusters.eterm
    cookie         :: atom(),                  %% per-peer cookie
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

init(#{cluster_id := Id, members := Configured, cookie := CookieBin}) ->
    Cookie = binary_to_atom(CookieBin, utf8),
    RefreshMs = application:get_env(reckon_gateway, refresh_interval_ms, 30_000),
    logger:info("[reckon_gateway_cluster ~p] init members=~p cookie=<~b bytes> refresh=~bms",
                [Id, Configured, byte_size(CookieBin), RefreshMs]),
    State = #state{
        cluster_id    = Id,
        configured    = Configured,
        cookie        = Cookie,
        members       = [],
        status        = not_yet_connected,
        refresh_ms    = RefreshMs
    },
    {ok, State, {continue, connect}}.

handle_continue(connect, State) ->
    {noreply, do_connect(State)}.

handle_call(get_status, _From, #state{cluster_id = Id,
                                       configured = Configured,
                                       members    = Members,
                                       status     = Status,
                                       last_refresh = LR,
                                       last_error = LE} = State) ->
    Reply = #{
        cluster_id    => Id,
        configured    => Configured,
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
    publish_catalogue(Id, Connected, Stores, Status, Now),
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
    publish_catalogue(Id, NewMembers, Stores, Status, Now),
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
%% Single-mode reckon-db (as in parksim) keeps a per-node registry
%% that only reports the stores running on THAT node; cluster-mode
%% replicates within the cluster but `first-seen wins' dedup on
%% store_id keeps either case clean.
discover_stores(ClusterId, Members) ->
    All = lists:flatten([discover_one(ClusterId, M) || M <- Members]),
    dedup_entries(All).

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

dedup_entries(Entries) ->
    {_Seen, Out} = lists:foldl(
        fun(#{store_id := Id} = E, {Seen, Acc}) ->
            case sets:is_element(Id, Seen) of
                true  -> {Seen, Acc};
                false -> {sets:add_element(Id, Seen), [E | Acc]}
            end
        end, {sets:new(), []}, Entries),
    lists:reverse(Out).

publish_catalogue(ClusterId, Members, Stores, Status, Now) ->
    reckon_gateway_catalogue:publish(ClusterId, #{
        members      => Members,
        stores       => Stores,
        status       => Status,
        last_refresh => Now
    }).

