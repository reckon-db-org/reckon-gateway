%%% @doc The socket options both listeners bind with.
%%%
%%% `listen_ip' is the address to bind. Its default `{0,0,0,0}' means "every
%%% interface", and is served as the IPv6 any-address with `ipv6_v6only' off,
%%% so a client that resolves `localhost' to `::1' and one that resolves it to
%%% `127.0.0.1' reach the same listener (reckon-gateway#11). On a host without
%%% the IPv6 family that address is not available, so the default falls back to
%%% the IPv4 any-address with a warning rather than failing to boot.
%%%
%%% An address the operator named is taken literally: an IPv4 address binds
%%% IPv4, an IPv6 address binds dual-stack, and a value that parses as neither
%%% stops the gateway with an error naming it. A silent fallback to "every
%%% interface" is the one outcome a mistyped loopback address must never get.
%%%
%%% Until this module, neither listener passed an address or a family option
%%% (`reckon_gateway_http_listener:child_spec/0' gave ranch `[{port, Port}]',
%%% `reckon_gateway_sup' gave `grpc:start_server/4' an empty option list), so
%%% gen_tcp's IPv4 default applied and `listen_ip' was never read.
%%% @end
-module(reckon_gateway_listen_opts).

-export([bind/0, bind_or_raise/0, ranch_opts/1, grpc_options/1]).

-define(ANY4, {0, 0, 0, 0}).
-define(ANY6, {0, 0, 0, 0, 0, 0, 0, 0}).

-type bind_result() :: #{address := inet:ip_address(), family_opts := [term()]}.

%% @doc The address and family options to bind with, or why there are none.
-spec bind() -> {ok, bind_result()} | {error, term()}.
bind() ->
    case configured_ip() of
        {ok, ?ANY4} -> any_address();
        {ok, Ip} -> named_address(Ip);
        {error, Bad} -> {error, {invalid_listen_ip, Bad}}
    end.

%% @doc `bind/0' for a caller that cannot carry on without it: the reason
%% becomes a start failure that names the value.
-spec bind_or_raise() -> bind_result().
bind_or_raise() ->
    case bind() of
        {ok, Bound} -> Bound;
        {error, Reason} -> error(Reason)
    end.

%% @doc Ranch transport options for the HTTP listener.
-spec ranch_opts(inet:port_number()) -> [term()].
ranch_opts(Port) ->
    #{address := Address, family_opts := FamilyOpts} = bind_or_raise(),
    [{port, Port}, {ip, Address} | FamilyOpts].

%% @doc The option list for grpc:start_server/4. The vendored runtime builds
%% the socket options from `listen_on' and appends whatever `socket_opts' it
%% is given here, so the family flags travel by ranch options.
-spec grpc_options([term()]) -> [term()].
grpc_options([]) -> [];
grpc_options(FamilyOpts) -> [{ranch_opts, #{socket_opts => FamilyOpts}}].

%%====================================================================
%% Internal
%%====================================================================

%% The default, served dual-stack where the host has IPv6 and IPv4-only where
%% it does not. A host without the family is a host where the old bind worked,
%% so it keeps working.
any_address() ->
    case reckon_gateway_listen_family:inet6_available() of
        true ->
            {ok, #{address => ?ANY6, family_opts => [inet6, {ipv6_v6only, false}]}};
        false ->
            logger:warning(
              "IPv6 is not available on this host: the gateway binds the IPv4 "
              "any-address only, and a client that resolves localhost to ::1 "
              "will not reach it (reckon-gateway#11)", []),
            {ok, #{address => ?ANY4, family_opts => []}}
    end.

%% An address the operator named is not rewritten: an IPv6 address needs the
%% family it names, and asking for one the host does not have is an error, not
%% a quiet move to another address.
named_address(Ip) when tuple_size(Ip) =:= 4 ->
    {ok, #{address => Ip, family_opts => []}};
named_address(Ip) when tuple_size(Ip) =:= 8 ->
    case reckon_gateway_listen_family:inet6_available() of
        true -> {ok, #{address => Ip, family_opts => [inet6, {ipv6_v6only, false}]}};
        false -> {error, {ipv6_unavailable, Ip}}
    end.

configured_ip() ->
    case application:get_env(reckon_gateway, listen_ip) of
        {ok, Configured} -> parse_ip(Configured);
        undefined -> {ok, ?ANY4}
    end.

parse_ip(Ip) when tuple_size(Ip) =:= 4, is_integer(element(1, Ip)) -> {ok, Ip};
parse_ip(Ip) when tuple_size(Ip) =:= 8 -> {ok, Ip};
parse_ip(Ip) when is_binary(Ip) -> parse_ip(binary_to_list(Ip));
parse_ip(Ip) when is_list(Ip) -> parse_ip_string(Ip);
parse_ip(Other) -> {error, Other}.

parse_ip_string(Ip) ->
    case inet:parse_address(Ip) of
        {ok, Parsed} -> {ok, Parsed};
        {error, _} -> {error, Ip}
    end.
