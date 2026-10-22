%%% @doc The socket options both listeners bind with.
%%%
%%% `listen_ip' is the address to bind. Its default `{0,0,0,0}' means "every
%%% interface", and is served as the IPv6 any-address with `ipv6_v6only' off,
%%% so a client that resolves `localhost' to `::1' and one that resolves it to
%%% `127.0.0.1' reach the same listener (reckon-gateway#11).
%%%
%%% Until this module, neither listener passed an address or a family option
%%% (`reckon_gateway_http_listener:child_spec/0' gave ranch `[{port, Port}]',
%%% `reckon_gateway_sup' gave `grpc:start_server/4' an empty option list), so
%%% gen_tcp's IPv4 default applied and `listen_ip' was never read.
%%% @end
-module(reckon_gateway_listen_opts).

-export([bind_address/0, family_opts/0, ranch_opts/1,
         grpc_listen_on/1, grpc_options/0]).

-define(ANY6, {0, 0, 0, 0, 0, 0, 0, 0}).

-type address() :: inet:ip_address().

%% @doc The address to bind. The IPv4 any-address is served as the IPv6
%% any-address, which is the only socket that can carry both families.
-spec bind_address() -> address().
bind_address() ->
    case listen_ip() of
        {0, 0, 0, 0} -> ?ANY6;
        Ip -> Ip
    end.

%% @doc Family and dual-stack options that belong with bind_address/0. An
%% IPv4 address takes none: it binds an IPv4 socket, as configured.
-spec family_opts() -> [term()].
family_opts() ->
    case bind_address() of
        {_, _, _, _} -> [];
        {_, _, _, _, _, _, _, _} -> [inet6, {ipv6_v6only, false}]
    end.

%% @doc Ranch transport options for the HTTP listener.
-spec ranch_opts(inet:port_number()) -> [term()].
ranch_opts(Port) ->
    [{port, Port}, {ip, bind_address()} | family_opts()].

%% @doc The `listen_on' argument for grpc:start_server/4.
-spec grpc_listen_on(inet:port_number()) -> {address(), inet:port_number()}.
grpc_listen_on(Port) ->
    {bind_address(), Port}.

%% @doc The option list for grpc:start_server/4. The vendored runtime builds
%% the socket options from `listen_on' and appends whatever `socket_opts' it
%% is given here, so the family flags travel by ranch options.
-spec grpc_options() -> [term()].
grpc_options() ->
    case family_opts() of
        [] -> [];
        FamilyOpts -> [{ranch_opts, #{socket_opts => FamilyOpts}}]
    end.

%%====================================================================
%% Internal
%%====================================================================

-spec listen_ip() -> address().
listen_ip() ->
    case application:get_env(reckon_gateway, listen_ip) of
        {ok, Configured} -> parse_ip(Configured);
        undefined -> ?ANY6
    end.

parse_ip({_, _, _, _} = Ip4) -> Ip4;
parse_ip({_, _, _, _, _, _, _, _} = Ip6) -> Ip6;
parse_ip(Ip) when is_binary(Ip) -> parse_ip(binary_to_list(Ip));
parse_ip(Ip) when is_list(Ip) -> parse_ip_string(Ip);
parse_ip(_Other) -> ?ANY6.

parse_ip_string(Ip) ->
    case inet:parse_address(Ip) of
        {ok, Parsed} -> Parsed;
        {error, _} -> ?ANY6
    end.
