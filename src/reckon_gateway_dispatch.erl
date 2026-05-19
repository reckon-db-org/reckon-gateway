%%% @doc Catalogue-mode dispatch helper. Every gRPC handler that
%%% used to call `reckon_gater_api:F(StoreId, ...)' locally now
%%% calls `reckon_gateway_dispatch:call(F, [StoreId | Args])'.
%%% The helper:
%%%
%%%   1. Looks up the cluster owning StoreId via the catalogue.
%%%   2. Picks a healthy member.
%%%   3. Invokes `reckon_gater_api:F(StoreId, ...)' on that member
%%%      via Erlang dist `rpc:call/4'.
%%%
%%% Error mapping:
%%%
%%%   - Catalogue has no entry for StoreId: `{error, store_unknown}'.
%%%   - Cluster is currently unreachable: `{error, cluster_unavailable}'.
%%%   - rpc:call returns `{badrpc, _}': `{error, {rpc_failed, Why}}'.
%%%
%%% These map cleanly to gRPC codes in the handlers
%%% (NotFound / Unavailable / Internal).
-module(reckon_gateway_dispatch).

-export([call/2, call/3]).

-define(DEFAULT_TIMEOUT_MS, 5000).

%% @doc Dispatch a reckon_gater_api function call across dist.
%% Args MUST be a non-empty list whose first element is the store_id atom.
-spec call(atom(), [term()]) -> term().
call(Fn, Args) ->
    call(Fn, Args, ?DEFAULT_TIMEOUT_MS).

-spec call(atom(), [term()], pos_integer() | infinity) -> term().
call(Fn, [StoreId | _] = Args, Timeout) when is_atom(StoreId) ->
    case reckon_gateway_catalogue:lookup(StoreId) of
        {ok, _ClusterId, Members, ApiModule} ->
            case pick_member(Members) of
                {ok, Member} ->
                    invoke(Member, ApiModule, Fn, Args, Timeout);
                error ->
                    {error, cluster_unavailable}
            end;
        {error, not_found} ->
            {error, store_unknown};
        {error, unreachable} ->
            {error, cluster_unavailable}
    end.

%% First healthy member wins. Future iteration can round-robin or
%% prefer the gateway-local-network-closest member.
pick_member([])             -> error;
pick_member([Member | _])   -> {ok, Member}.

invoke(Member, ApiModule, Fn, Args, Timeout) ->
    case rpc:call(Member, ApiModule, Fn, Args, Timeout) of
        {badrpc, Reason} ->
            {error, {rpc_failed, Member, Reason}};
        Result ->
            Result
    end.
