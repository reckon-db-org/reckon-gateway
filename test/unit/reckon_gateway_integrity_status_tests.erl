%%% @doc Unit tests for reckon_gateway_http_health:integrity_status/1 —
%%% the dispatched per-store integrity fetch that replaced the gateway's
%%% (always-empty for catalogue-federated stores) local read.
-module(reckon_gateway_integrity_status_tests).

-include_lib("eunit/include/eunit.hrl").

-define(STORE, gw_integrity_test_store).
-define(DISABLED, #{enabled => false, algo => <<>>, key_id => 0}).

with_dispatch(Fun, Body) ->
    meck:new(reckon_gateway_dispatch, [passthrough]),
    meck:expect(reckon_gateway_dispatch, call, Fun),
    try Body() after meck:unload(reckon_gateway_dispatch) end.

%% A store reporting integrity ON is forwarded verbatim.
forwards_enabled_status_test() ->
    Status = #{enabled => true, algo => <<"sha256-deterministic-etf-v1">>, key_id => 1},
    Got = with_dispatch(
        fun(integrity_status, [?STORE]) -> {ok, Status} end,
        fun() -> reckon_gateway_http_health:integrity_status(?STORE) end),
    ?assertEqual(Status, Got).

%% A store reporting integrity OFF is forwarded verbatim.
forwards_disabled_status_test() ->
    Got = with_dispatch(
        fun(integrity_status, [?STORE]) -> {ok, ?DISABLED} end,
        fun() -> reckon_gateway_http_health:integrity_status(?STORE) end),
    ?assertEqual(?DISABLED, Got).

%% An unreachable store (dispatch error) degrades to disabled, not a crash.
unreachable_store_degrades_to_disabled_test() ->
    Got = with_dispatch(
        fun(integrity_status, [?STORE]) -> {error, {rpc_failed, node, boom}} end,
        fun() -> reckon_gateway_http_health:integrity_status(?STORE) end),
    ?assertEqual(?DISABLED, Got).

%% A malformed reply also degrades to disabled rather than propagating.
malformed_reply_degrades_to_disabled_test() ->
    Got = with_dispatch(
        fun(integrity_status, [?STORE]) -> {ok, not_a_map} end,
        fun() -> reckon_gateway_http_health:integrity_status(?STORE) end),
    ?assertEqual(?DISABLED, Got).
