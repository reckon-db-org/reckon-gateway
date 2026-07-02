%% @doc Telemetry events for reckon-gateway
%%
%% The gateway is the polyglot ingress: every store operation from an
%% HTTP/JSON or gRPC client is routed through `reckon_gateway_dispatch'
%% to a member of the owning cluster, and the fleet of federated stores
%% is tracked by `reckon_gateway_catalogue'. These events instrument
%% both — request throughput/latency/failure at the dispatch choke
%% point, and fleet membership changes at the catalogue.
%%
%% Each event documents its Measurements (numeric — for counters and
%% histograms) and Metadata (contextual — for labels) inline so a
%% consumer can attach a handler without reading the emit sites.
%% Durations are microseconds. Attach via
%% `reckon_gateway_telemetry:attach/3'.
%%
%% @author rgfaber

-ifndef(RECKON_GATEWAY_TELEMETRY_HRL).
-define(RECKON_GATEWAY_TELEMETRY_HRL, true).

%%====================================================================
%% Dispatch Events (the request path)
%%
%% Emitted around every reckon_gateway_dispatch:call/2,3 — i.e. every
%% store operation that crosses from the gateway to a cluster member.
%% Start/stop bracket a success; start/error bracket a failure. `op' is
%% the reckon_gater_api function name (append_events, get_streams, …).
%%====================================================================

%% Emitted when a dispatch begins.
%% Measurements: system_time
%% Metadata: store_id, op
-define(GW_DISPATCH_START, [reckon_gateway, dispatch, start]).

%% Emitted when a dispatch returns a non-error result.
%% Measurements: duration
%% Metadata: store_id, op
-define(GW_DISPATCH_STOP, [reckon_gateway, dispatch, stop]).

%% Emitted when a dispatch fails. `reason' is the classified failure:
%% store_unknown | cluster_unavailable | rpc_failed | Other.
%% Measurements: duration
%% Metadata: store_id, op, reason
-define(GW_DISPATCH_ERROR, [reckon_gateway, dispatch, error]).

%%====================================================================
%% Catalogue Events (the federated fleet)
%%
%% Emitted by reckon_gateway_catalogue when a store first appears in or
%% leaves the merged catalogue. Mirrors the SSE store_announced /
%% store_retired stream the admin UI consumes.
%%====================================================================

%% Emitted when a store_id is first claimed by a cluster in the catalogue.
%% Measurements: system_time
%% Metadata: store_id, cluster_id
-define(GW_STORE_ANNOUNCED, [reckon_gateway, store, announced]).

%% Emitted when a store_id is dropped from the catalogue.
%% Measurements: system_time
%% Metadata: store_id, cluster_id
-define(GW_STORE_RETIRED, [reckon_gateway, store, retired]).

-endif. %% RECKON_GATEWAY_TELEMETRY_HRL
