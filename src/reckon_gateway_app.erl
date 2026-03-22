%% @doc ReckonDB gRPC Gateway application.
%%
%% Starts the gRPC server that exposes ReckonDB operations
%% to non-BEAM clients over gRPC.
-module(reckon_gateway_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    reckon_gateway_sup:start_link().

stop(_State) ->
    ok.
