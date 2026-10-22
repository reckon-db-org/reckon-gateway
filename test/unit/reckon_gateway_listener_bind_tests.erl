%%% @doc The listeners accept on both loopbacks (reckon-gateway#11).
%%%
%%% Each test starts the real listener — `reckon_gateway_http_listener:child_spec/0'
%%% and `grpc:start_server/4' with the options `reckon_gateway_sup' passes — on
%%% an ephemeral port, then dials it as a client would: `127.0.0.1' for IPv4 and
%%% `::1' for IPv6. Both must connect. A listener that takes gen_tcp's IPv4
%%% default fails the `::1' dial, which is the defect the issue records.
%%% @end
-module(reckon_gateway_listener_bind_tests).

-behaviour(supervisor).

-include_lib("eunit/include/eunit.hrl").

-export([init/1]).

-define(HTTP, reckon_gateway_http).
-define(GRPC, reckon_gateway_grpc_bind_test).
-define(ANY6, {0, 0, 0, 0, 0, 0, 0, 0}).
-define(LOOPBACK4, {127, 0, 0, 1}).
-define(LOOPBACK6, {0, 0, 0, 0, 0, 0, 0, 1}).

%%====================================================================
%% Supervisor, so the listener runs under a real supervision tree
%%====================================================================

init(Children) ->
    {ok, {{one_for_one, 5, 30}, Children}}.

%%====================================================================
%% HTTP listener
%%====================================================================

http_listener_accepts_ipv4_and_ipv6_test_() ->
    {timeout, 60,
     fun() ->
         with_listen_ip(unset, fun() ->
             {Sup, Port} = start_http_listener(),
             try
                 ?assertMatch({ok, _}, dial(inet, Port)),
                 ?assertMatch({ok, _}, dial(inet6, Port))
             after
                 stop_supervisor(Sup)
             end
         end)
     end}.

%% listen_ip is honoured: naming an IPv4 address binds that address only, so
%% the IPv6 loopback is refused. This is what makes listen_ip more than a
%% comment in the config.
http_listener_honours_an_ipv4_listen_ip_test_() ->
    {timeout, 60,
     fun() ->
         with_listen_ip(?LOOPBACK4, fun() ->
             {Sup, Port} = start_http_listener(),
             try
                 ?assertMatch({ok, _}, dial(inet, Port)),
                 ?assertMatch({error, econnrefused}, dial(inet6, Port))
             after
                 stop_supervisor(Sup)
             end
         end)
     end}.

%%====================================================================
%% gRPC listener
%%====================================================================

grpc_listener_accepts_ipv4_and_ipv6_test_() ->
    {timeout, 60,
     fun() ->
         with_listen_ip(unset, fun() ->
             {ok, _} = application:ensure_all_started(cowboy),
             {ok, _} = application:ensure_all_started(grpc),
             {ok, _} = reckon_gateway_grpc_listener:start_server(
                         ?GRPC, 0, #{protos => [], services => #{}}),
             try
                 Port = ranch:get_port(?GRPC),
                 ?assert(Port > 0),
                 ?assertMatch({ok, _}, dial(inet, Port)),
                 ?assertMatch({ok, _}, dial(inet6, Port))
             after
                 grpc:stop_server(?GRPC)
             end
         end)
     end}.

%%====================================================================
%% Helpers
%%====================================================================

start_http_listener() ->
    {ok, _} = application:ensure_all_started(cowboy),
    ok = application:set_env(reckon_gateway, http_port, 0),
    Child = reckon_gateway_http_listener:child_spec(),
    {ok, Sup} = supervisor:start_link(?MODULE, [Child]),
    {Sup, ranch:get_port(?HTTP)}.

stop_supervisor(Sup) ->
    unlink(Sup),
    exit(Sup, shutdown),
    wait_for_exit(Sup, 50).

wait_for_exit(_Pid, 0) -> ok;
wait_for_exit(Pid, N) ->
    case is_process_alive(Pid) of
        false -> ok;
        true -> timer:sleep(20), wait_for_exit(Pid, N - 1)
    end.

%% A client dial, the way curl or an SDK does it: one address family, no
%% fallback, short timeout so a refused or dropped connect fails the test
%% quickly instead of hanging it.
dial(Family, Port) ->
    Address = case Family of
                  inet6 -> ?LOOPBACK6;
                  inet -> ?LOOPBACK4
              end,
    gen_tcp:connect(Address, Port, [Family, binary, {active, false}], 2000).

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
