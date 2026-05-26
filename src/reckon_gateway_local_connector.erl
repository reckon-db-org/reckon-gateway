%%% @doc Connector that publishes the local node's stores into the
%%% gateway catalogue.
%%%
%%% Sibling to `reckon_gateway_cluster_connector', which polls REMOTE
%%% clusters via Erlang dist. This module polls the LOCAL node's
%%% `reckon_db_store_registry' (no dist round-trip — direct
%%% function call) and publishes the merged store list to the
%%% catalogue under the operator-set `cluster_id'.
%%%
%%% The local connector is started by `reckon_gateway_sup' only when
%%% the embedded store mode is enabled. The cluster_id used for
%%% publishing comes from `RECKON_GATEWAY_LOCAL_CLUSTER_ID' (default
%%% `local') — this is the label that appears in
%%% `StoresService.ListStores' responses and in the
%%% `AdminService.GetCatalogueStatus' snapshot.
%%%
%%% Cluster-wide visibility: `reckon_db_store_registry' is itself
%%% pg-replicated, so when the local node is dist-connected to peer
%%% gateways in cluster mode, `list_stores/0' returns the merged
%%% cluster-wide list — this connector publishes that view. Other
%%% gateways' cluster_connectors will see the SAME store_ids via
%%% their own dist connections; the catalogue's first-seen-wins
%%% collision logic handles this gracefully.
-module(reckon_gateway_local_connector).
-behaviour(gen_server).

-export([start_link/1, child_spec/1, status/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(DEFAULT_REFRESH_MS, 5_000).

-record(state, {
    cluster_id     :: atom(),
    refresh_ms     :: pos_integer(),
    refresh_timer  :: reference() | undefined,
    last_refresh   :: integer() | undefined,
    last_count     :: non_neg_integer()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link(atom()) -> {ok, pid()} | {error, term()}.
start_link(ClusterId) when is_atom(ClusterId) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, ClusterId, []).

-spec child_spec(atom()) -> supervisor:child_spec().
child_spec(ClusterId) ->
    #{id       => ?MODULE,
      start    => {?MODULE, start_link, [ClusterId]},
      restart  => permanent,
      shutdown => 5000,
      type     => worker,
      modules  => [?MODULE]}.

-spec status() -> #{atom() => term()}.
status() ->
    gen_server:call(?MODULE, get_status).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init(ClusterId) ->
    RefreshMs = application:get_env(reckon_gateway, refresh_interval_ms,
                                    ?DEFAULT_REFRESH_MS),
    logger:info("[reckon_gateway_local_connector] init cluster_id=~p "
                "refresh=~bms",
                [ClusterId, RefreshMs]),
    self() ! refresh,
    {ok, #state{cluster_id   = ClusterId,
                refresh_ms   = RefreshMs,
                last_count   = 0}}.

handle_call(get_status, _From,
            #state{cluster_id = Id, last_refresh = LR, last_count = Count} = State) ->
    Reply = #{cluster_id   => Id,
              last_refresh => LR,
              store_count  => Count,
              status       => up,
              source       => local},
    {reply, Reply, State};
handle_call(_Msg, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast(_Msg, State) -> {noreply, State}.

handle_info(refresh, State) ->
    NewState = do_refresh(State),
    {noreply, schedule(NewState)};
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, #state{cluster_id = ClusterId}) ->
    %% Tell the catalogue the local cluster is going away so it cleans
    %% up its entries. Best-effort; the catalogue is normally torn down
    %% after us anyway.
    catch reckon_gateway_catalogue:remove(ClusterId),
    ok;
terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal
%%====================================================================

do_refresh(#state{cluster_id = ClusterId} = State) ->
    Now = erlang:system_time(millisecond),
    case reckon_db_store_registry:list_stores() of
        {ok, Entries} ->
            %% Entries are already the merged cluster-wide list (pg
            %% replicates across the embedded reckon-db cluster).
            %% Publish them under our operator-set cluster_id.
            Info = #{members      => [node()],
                     api_module   => reckon_gater_api,
                     stores       => Entries,
                     status       => up,
                     last_refresh => Now},
            reckon_gateway_catalogue:publish(ClusterId, Info),
            State#state{last_refresh = Now, last_count = length(Entries)};
        {error, Reason} ->
            logger:warning("[reckon_gateway_local_connector] registry error: ~p",
                           [Reason]),
            Info = #{members      => [node()],
                     api_module   => reckon_gater_api,
                     stores       => [],
                     status       => degraded,
                     last_refresh => Now},
            reckon_gateway_catalogue:publish(ClusterId, Info),
            State#state{last_refresh = Now, last_count = 0}
    end.

schedule(#state{refresh_ms = Ms} = State) ->
    Ref = erlang:send_after(Ms, self(), refresh),
    State#state{refresh_timer = Ref}.
