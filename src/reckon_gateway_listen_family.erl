%%% @doc Whether this host can bind an IPv6 socket.
%%%
%%% Its own module so the answer is a seam: a test can stand a stand-in in for
%%% the kernel, and the listeners' behaviour on a host without IPv6 (a kernel
%%% booted with ipv6.disable=1, a container without the family) is decided in
%%% one place and can be exercised without one (reckon-gateway#11).
%%% @end
-module(reckon_gateway_listen_family).

-export([inet6_available/0]).

%% @doc True when a loopback IPv6 socket can be opened here; false when the
%% family is absent (EAFNOSUPPORT and friends).
-spec inet6_available() -> boolean().
inet6_available() ->
    case gen_tcp:listen(0, [inet6, {ip, {0, 0, 0, 0, 0, 0, 0, 1}},
                            {active, false}]) of
        {ok, Socket} ->
            gen_tcp:close(Socket),
            true;
        {error, _Reason} ->
            false
    end.
