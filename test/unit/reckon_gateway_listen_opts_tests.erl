%%% @doc Unit tests for the bind options both listeners use.
%%%
%%% The point of the module is that `listen_ip' decides the bind: the default
%%% (unset, or the legacy `{0,0,0,0}') is served as the IPv6 any-address with
%%% `ipv6_v6only' off so both loopbacks reach one socket, and an operator who
%%% names an address gets exactly that address (reckon-gateway#11).
%%% @end
-module(reckon_gateway_listen_opts_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ANY6, {0, 0, 0, 0, 0, 0, 0, 0}).

unset_listen_ip_binds_ipv6_any_test() ->
    with_listen_ip(unset, fun() ->
        ?assertEqual(?ANY6, reckon_gateway_listen_opts:bind_address()),
        ?assertEqual([inet6, {ipv6_v6only, false}],
                     reckon_gateway_listen_opts:family_opts())
    end).

ipv4_any_is_served_as_ipv6_any_test() ->
    with_listen_ip({0, 0, 0, 0}, fun() ->
        ?assertEqual(?ANY6, reckon_gateway_listen_opts:bind_address()),
        ?assertEqual([inet6, {ipv6_v6only, false}],
                     reckon_gateway_listen_opts:family_opts())
    end).

explicit_ipv4_address_is_bound_as_is_test() ->
    with_listen_ip({127, 0, 0, 1}, fun() ->
        ?assertEqual({127, 0, 0, 1}, reckon_gateway_listen_opts:bind_address()),
        ?assertEqual([], reckon_gateway_listen_opts:family_opts())
    end).

explicit_ipv6_address_keeps_dual_stack_test() ->
    with_listen_ip({0, 0, 0, 0, 0, 0, 0, 1}, fun() ->
        ?assertEqual({0, 0, 0, 0, 0, 0, 0, 1},
                     reckon_gateway_listen_opts:bind_address()),
        ?assertEqual([inet6, {ipv6_v6only, false}],
                     reckon_gateway_listen_opts:family_opts())
    end).

address_given_as_a_string_is_parsed_test() ->
    with_listen_ip("127.0.0.1", fun() ->
        ?assertEqual({127, 0, 0, 1}, reckon_gateway_listen_opts:bind_address())
    end).

unparseable_address_falls_back_to_any_test() ->
    with_listen_ip(<<"not-an-address">>, fun() ->
        ?assertEqual(?ANY6, reckon_gateway_listen_opts:bind_address())
    end).

ranch_opts_carry_port_address_and_family_test() ->
    with_listen_ip(unset, fun() ->
        ?assertEqual([{port, 0}, {ip, ?ANY6}, inet6, {ipv6_v6only, false}],
                     reckon_gateway_listen_opts:ranch_opts(0))
    end).

ranch_opts_for_ipv4_carry_no_family_flags_test() ->
    with_listen_ip({10, 0, 0, 5}, fun() ->
        ?assertEqual([{port, 8080}, {ip, {10, 0, 0, 5}}],
                     reckon_gateway_listen_opts:ranch_opts(8080))
    end).

grpc_listen_on_carries_the_bind_address_test() ->
    with_listen_ip(unset, fun() ->
        ?assertEqual({?ANY6, 50051}, reckon_gateway_listen_opts:grpc_listen_on(50051))
    end).

grpc_options_carry_family_flags_through_ranch_test() ->
    with_listen_ip(unset, fun() ->
        ?assertEqual([{ranch_opts, #{socket_opts => [inet6, {ipv6_v6only, false}]}}],
                     reckon_gateway_listen_opts:grpc_options())
    end).

grpc_options_for_ipv4_are_empty_test() ->
    with_listen_ip({127, 0, 0, 1}, fun() ->
        ?assertEqual([], reckon_gateway_listen_opts:grpc_options())
    end).

%%====================================================================
%% Helpers
%%====================================================================

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
