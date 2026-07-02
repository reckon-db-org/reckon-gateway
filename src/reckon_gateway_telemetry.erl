%% @doc Telemetry facade for reckon-gateway.
%%
%% Provides a default logger handler for gateway telemetry events plus
%% utilities for attaching/detaching custom handlers (e.g. an
%% OpenTelemetry or Prometheus exporter for datacenter deployments).
%% The event catalogue lives in reckon_gateway_telemetry.hrl.
%%
%% == Usage ==
%%
%% Attach the default logger handler (done at app boot when the
%% `telemetry_handlers' env includes `logger'):
%%   ok = reckon_gateway_telemetry:attach_default_handler().
%%
%% Attach a custom handler across all gateway events:
%%   ok = reckon_gateway_telemetry:attach(my_id, fun my_mod:handle/4, #{}).
%%
%% Emit an event:
%%   reckon_gateway_telemetry:emit(?GW_DISPATCH_STOP,
%%                                 #{duration => 1200},
%%                                 #{store_id => my_store, op => get_streams}).
%%
%% @author rgfaber

-module(reckon_gateway_telemetry).

-include("reckon_gateway_telemetry.hrl").

-export([
    attach_default_handler/0,
    detach_default_handler/0,
    attach/3,
    detach/1,
    emit/3,
    all_events/0,
    handle_event/4
]).

-define(HANDLER_ID, reckon_gateway_telemetry_handler).

%%====================================================================
%% API
%%====================================================================

%% @doc Attach the default logger handler for all gateway events.
-spec attach_default_handler() -> ok | {error, already_exists}.
attach_default_handler() ->
    telemetry:attach_many(?HANDLER_ID, all_events(), fun ?MODULE:handle_event/4, #{}).

%% @doc Detach the default logger handler.
-spec detach_default_handler() -> ok | {error, not_found}.
detach_default_handler() ->
    telemetry:detach(?HANDLER_ID).

%% @doc Attach a custom handler across all gateway events.
-spec attach(term(), fun((telemetry:event_name(), telemetry:event_measurements(),
                          telemetry:event_metadata(), term()) -> ok), term()) ->
    ok | {error, already_exists}.
attach(HandlerId, HandlerFun, Config) ->
    telemetry:attach_many(HandlerId, all_events(), HandlerFun, Config).

%% @doc Detach a handler by id.
-spec detach(term()) -> ok | {error, not_found}.
detach(HandlerId) ->
    telemetry:detach(HandlerId).

%% @doc Emit a telemetry event.
-spec emit(telemetry:event_name(), telemetry:event_measurements(),
           telemetry:event_metadata()) -> ok.
emit(Event, Measurements, Metadata) ->
    telemetry:execute(Event, Measurements, Metadata).

%% @doc Every event the gateway emits. Handy for `attach_many'.
-spec all_events() -> [telemetry:event_name()].
all_events() ->
    [
        ?GW_DISPATCH_START,
        ?GW_DISPATCH_STOP,
        ?GW_DISPATCH_ERROR,
        ?GW_STORE_ANNOUNCED,
        ?GW_STORE_RETIRED
    ].

%%====================================================================
%% Default logger handler
%%====================================================================

-spec handle_event(
    telemetry:event_name(),
    telemetry:event_measurements(),
    telemetry:event_metadata(),
    term()
) -> ok.
handle_event(?GW_DISPATCH_START, _Measurements, Meta, _Config) ->
    #{store_id := StoreId, op := Op} = Meta,
    logger:debug("dispatch start: store=~p op=~p", [StoreId, Op]),
    ok;

handle_event(?GW_DISPATCH_STOP, Measurements, Meta, _Config) ->
    Duration = maps:get(duration, Measurements, 0),
    #{store_id := StoreId, op := Op} = Meta,
    logger:debug("dispatch ok: store=~p op=~p duration=~pus", [StoreId, Op, Duration]),
    ok;

handle_event(?GW_DISPATCH_ERROR, Measurements, Meta, _Config) ->
    Duration = maps:get(duration, Measurements, 0),
    #{store_id := StoreId, op := Op, reason := Reason} = Meta,
    logger:warning("dispatch error: store=~p op=~p reason=~p duration=~pus",
                   [StoreId, Op, Reason, Duration]),
    ok;

handle_event(?GW_STORE_ANNOUNCED, _Measurements, Meta, _Config) ->
    #{store_id := StoreId, cluster_id := ClusterId} = Meta,
    logger:info("store announced: store=~p cluster=~p", [StoreId, ClusterId]),
    ok;

handle_event(?GW_STORE_RETIRED, _Measurements, Meta, _Config) ->
    #{store_id := StoreId, cluster_id := ClusterId} = Meta,
    logger:info("store retired: store=~p cluster=~p", [StoreId, ClusterId]),
    ok;

handle_event(Event, Measurements, Meta, _Config) ->
    logger:debug("telemetry event: ~p measurements=~p meta=~p",
                 [Event, Measurements, Meta]),
    ok.
