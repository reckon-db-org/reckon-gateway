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

-include("reckon_gateway_telemetry.hrl").

-export([call/2, call/3]).

-define(DEFAULT_TIMEOUT_MS, 5000).

%% @doc Dispatch a reckon_gater_api function call across dist.
%% Args MUST be a non-empty list whose first element is the store_id atom.
-spec call(atom(), [term()]) -> term().
call(Fn, Args) ->
    call(Fn, Args, ?DEFAULT_TIMEOUT_MS).

-spec call(atom(), [term()], pos_integer() | infinity) -> term().
call(Fn, [StoreId | _] = Args, Timeout) when is_atom(StoreId) ->
    Start = erlang:monotonic_time(microsecond),
    telemetry:execute(?GW_DISPATCH_START,
                      #{system_time => erlang:system_time(millisecond)},
                      #{store_id => StoreId, op => Fn}),
    Result = dispatch_lookup(reckon_gateway_catalogue:lookup(StoreId), StoreId, Fn, Args, Timeout),
    emit_dispatch_result(Fn, StoreId, Start, Result),
    Result.

%% @private Classify the dispatch outcome into a stop (success) or
%% error telemetry event. `{error, Reason}' — including the internal
%% store_unknown / cluster_unavailable / {rpc_failed, _, _} shapes — is
%% a failure; anything else is a success.
emit_dispatch_result(Fn, StoreId, Start, Result) ->
    Duration = erlang:monotonic_time(microsecond) - Start,
    case Result of
        {error, Reason} ->
            telemetry:execute(?GW_DISPATCH_ERROR,
                              #{duration => Duration},
                              #{store_id => StoreId, op => Fn,
                                reason => dispatch_reason(Reason)});
        _ ->
            telemetry:execute(?GW_DISPATCH_STOP,
                              #{duration => Duration},
                              #{store_id => StoreId, op => Fn})
    end.

%% @private Keep the reason label low-cardinality: collapse the
%% {rpc_failed, Member, Why} tuple to the atom `rpc_failed'.
dispatch_reason({rpc_failed, _Member, _Why}) -> rpc_failed;
dispatch_reason(Reason) when is_atom(Reason) -> Reason;
dispatch_reason(_Reason)                      -> other.

dispatch_lookup({ok, _ClusterId, Members, ApiModule}, StoreId, Fn, Args, Timeout) ->
    dispatch_member(pick_member(Members), ApiModule, StoreId, Fn, Args, Timeout);
dispatch_lookup({error, not_found}, StoreId, Fn, _Args, _Timeout) ->
    logger:debug("dispatch: store_unknown ~p (op=~p)", [StoreId, Fn]),
    {error, store_unknown};
dispatch_lookup({error, unreachable}, StoreId, Fn, _Args, _Timeout) ->
    logger:warning("dispatch: catalogue unreachable for ~p (op=~p)", [StoreId, Fn]),
    {error, cluster_unavailable}.

dispatch_member({ok, Member}, ApiModule, _StoreId, Fn, Args, Timeout) ->
    invoke(Member, ApiModule, Fn, Args, Timeout);
dispatch_member(error, _ApiModule, StoreId, Fn, _Args, _Timeout) ->
    logger:warning("dispatch: ~p has no healthy member for ~p", [StoreId, Fn]),
    {error, cluster_unavailable}.

%% First healthy member wins. Future iteration can round-robin or
%% prefer the gateway-local-network-closest member.
pick_member([])             -> error;
pick_member([Member | _])   -> {ok, Member}.

invoke(Member, ApiModule, Fn, Args, Timeout) ->
    case rpc:call(Member, ApiModule, Fn, Args, Timeout) of
        {badrpc, Reason} ->
            logger:warning(
                "dispatch: rpc ~p:~p/~p on ~p failed: ~p",
                [ApiModule, Fn, length(Args), Member, Reason]),
            {error, {rpc_failed, Member, Reason}};
        Result ->
            Result
    end.
