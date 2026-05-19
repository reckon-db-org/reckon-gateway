%%% @doc Supervisor over the catalogue's per-cluster connectors.
%%% Loads the cluster catalogue from `clusters.eterm' at boot,
%%% spawns one `reckon_gateway_cluster_connector' per entry.
%%%
%%% When the config file is missing/empty/invalid the supervisor
%%% boots with zero children — the gateway stays up and every data
%%% RPC will (once dispatch lands) return `store_unknown'.
%%%
%%% Restart strategy is one_for_one: a failed connector for cluster A
%%% does not cycle connectors for clusters B, C, ...
-module(reckon_gateway_clusters_sup).
-behaviour(supervisor).

-export([start_link/0]).
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
