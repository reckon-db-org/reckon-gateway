%% @doc ReckonDB gRPC Gateway application.
%%
%% Starts the gRPC server that exposes ReckonDB operations
%% to non-BEAM clients over gRPC.
-module(reckon_gateway_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ok = start_telemetry_handlers(),
    reckon_gateway_sup:start_link().

stop(_State) ->
    ok.

%% @private Attach configured telemetry handlers. Defaults to the
%% built-in logger handler; set `telemetry_handlers' to `[]' to run
%% silent, or add exporters (OpenTelemetry / Prometheus) alongside
%% `logger'. Mirrors reckon_db_app:start_telemetry_handlers/0.
-spec start_telemetry_handlers() -> ok.
start_telemetry_handlers() ->
    Handlers = application:get_env(reckon_gateway, telemetry_handlers, [logger]),
    lists:foreach(fun attach_handler/1, Handlers),
    ok.

-spec attach_handler(logger | atom()) -> ok.
attach_handler(logger) ->
    _ = reckon_gateway_telemetry:attach_default_handler(),
    ok;
attach_handler(_Other) ->
    ok.
