%%% @doc Unit tests for the bind options both listeners use.
%%%
%%% The default is served as the IPv6 any-address with `ipv6_v6only' off, so
%%% both loopbacks reach one socket — and on a host without the IPv6 family it
%%% falls back to the IPv4 any-address instead of refusing to boot. An address
%%% the operator names is taken literally, and one that parses as no address at
%%% all stops the gateway rather than quietly binding every interface
%%% (reckon-gateway#11).
%%% @end
-module(reckon_gateway_listen_opts_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ANY4, {0, 0, 0, 0}).
-define(ANY6, {0, 0, 0, 0, 0, 0, 0, 0}).
-define(DUAL, [inet6, {ipv6_v6only, false}]).

%%====================================================================
%% The default address
%%====================================================================

default_binds_ipv6_any_when_the_family_is_there_test() ->
    with_inputs(unset, true, fun() ->
        ?assertEqual({ok, #{address => ?ANY6, family_opts => ?DUAL}},
                     reckon_gateway_listen_opts:bind())
    end).

ipv4_any_is_served_dual_stack_when_ipv6_is_there_test() ->
    with_inputs(?ANY4, true, fun() ->
        ?assertEqual({ok, #{address => ?ANY6, family_opts => ?DUAL}},
                     reckon_gateway_listen_opts:bind())
    end).

%% A kernel booted without IPv6 is a host the old bind worked on: the default
%% keeps working there, on IPv4 only, and says so in the log.
default_falls_back_to_ipv4_on_a_host_without_ipv6_test() ->
    with_inputs(?ANY4, false, fun() ->
        ?assertEqual({ok, #{address => ?ANY4, family_opts => []}},
                     reckon_gateway_listen_opts:bind()),
        ?assertEqual([{port, 8080}, {ip, ?ANY4}],
                     reckon_gateway_listen_opts:ranch_opts(8080))
    end).

%%====================================================================
%% An address the operator named
%%====================================================================

explicit_ipv4_address_is_bound_as_is_test() ->
    with_inputs({127, 0, 0, 1}, true, fun() ->
        ?assertEqual({ok, #{address => {127, 0, 0, 1}, family_opts => []}},
                     reckon_gateway_listen_opts:bind())
    end).

explicit_ipv6_address_keeps_dual_stack_test() ->
    with_inputs({0, 0, 0, 0, 0, 0, 0, 1}, true, fun() ->
        ?assertEqual({ok, #{address => {0, 0, 0, 0, 0, 0, 0, 1},
                            family_opts => ?DUAL}},
                     reckon_gateway_listen_opts:bind())
    end).

%% Asking for an IPv6 address on a host without the family is an error that
%% names the address, not a move to another one.
explicit_ipv6_address_on_a_host_without_ipv6_is_an_error_test() ->
    Ip = {0, 0, 0, 0, 0, 0, 0, 1},
    with_inputs(Ip, false, fun() ->
        ?assertEqual({error, {ipv6_unavailable, Ip}},
                     reckon_gateway_listen_opts:bind())
    end).

address_given_as_a_string_is_parsed_test() ->
    with_inputs("127.0.0.1", true, fun() ->
        ?assertEqual({ok, #{address => {127, 0, 0, 1}, family_opts => []}},
                     reckon_gateway_listen_opts:bind())
    end).

%% A mistyped address must not become "every interface": that is a public bind
%% where a loopback one was meant.
unparseable_address_refuses_to_start_test() ->
    with_inputs(<<"not-an-address">>, true, fun() ->
        ?assertEqual({error, {invalid_listen_ip, "not-an-address"}},
                     reckon_gateway_listen_opts:bind()),
        ?assertError({invalid_listen_ip, "not-an-address"},
                     reckon_gateway_listen_opts:bind_or_raise()),
        ?assertError({invalid_listen_ip, "not-an-address"},
                     reckon_gateway_listen_opts:ranch_opts(8080))
    end).

%%====================================================================
%% The option shapes the listeners consume
%%====================================================================

ranch_opts_carry_port_address_and_family_test() ->
    with_inputs(unset, true, fun() ->
        ?assertEqual([{port, 0}, {ip, ?ANY6} | ?DUAL],
                     reckon_gateway_listen_opts:ranch_opts(0))
    end).

ranch_opts_for_a_named_ipv4_address_carry_no_family_flags_test() ->
    with_inputs({10, 0, 0, 5}, true, fun() ->
        ?assertEqual([{port, 8080}, {ip, {10, 0, 0, 5}}],
                     reckon_gateway_listen_opts:ranch_opts(8080))
    end).

grpc_options_pass_family_flags_through_ranch_test() ->
    ?assertEqual([{ranch_opts, #{socket_opts => ?DUAL}}],
                 reckon_gateway_listen_opts:grpc_options(?DUAL)),
    ?assertEqual([], reckon_gateway_listen_opts:grpc_options([])).

%%====================================================================
%% Helpers
%%====================================================================

%% Both inputs at once: the address the config names and whether the host has
%% the IPv6 family. Composed here because nesting the two helpers at the call
%% site would evaluate the inner one eagerly.
with_inputs(Ip, Inet6Available, Fun) ->
    with_listen_ip(Ip, fun() -> with_inet6(Inet6Available, Fun) end).

with_listen_ip(unset, Fun) ->
    Previous = application:get_env(reckon_gateway, listen_ip),
    application:unset_env(reckon_gateway, listen_ip),
    try Fun() after restore(Previous) end;
with_listen_ip(Ip, Fun) ->
    Previous = application:get_env(reckon_gateway, listen_ip),
    application:set_env(reckon_gateway, listen_ip, Ip),
    try Fun() after restore(Previous) end.

restore({ok, Ip}) -> application:set_env(reckon_gateway, listen_ip, Ip);
restore(undefined) -> application:unset_env(reckon_gateway, listen_ip).

%% The seam for the family: a stand-in for the kernel, so the no-IPv6 host is
%% exercised without one.
with_inet6(Available, Fun) ->
    meck:new(reckon_gateway_listen_family, [passthrough]),
    meck:expect(reckon_gateway_listen_family, inet6_available, fun() -> Available end),
    try Fun() after meck:unload(reckon_gateway_listen_family) end.
