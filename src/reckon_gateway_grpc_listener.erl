%%% @doc The gRPC listener.
%%%
%%% One place where the gateway starts it, so the address it binds is decided
%%% next to the HTTP listener's rather than at the supervisor's call site
%%% (reckon-gateway#11).
%%% @end
-module(reckon_gateway_grpc_listener).

-export([start_server/3]).

-spec start_server(atom(), inet:port_number(), map()) -> {ok, pid()} | {error, term()}.
start_server(Name, Port, Services) ->
    grpc:start_server(Name,
                      reckon_gateway_listen_opts:grpc_listen_on(Port),
                      Services,
                      reckon_gateway_listen_opts:grpc_options()).
