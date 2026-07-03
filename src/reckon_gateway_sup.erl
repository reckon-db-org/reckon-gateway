%% @doc Top-level supervisor for the ReckonDB gRPC Gateway.
%%
%% Starts the grpc server (emqx/grpc-erl, cowboy-based HTTP/2).
-module(reckon_gateway_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, Port} = application:get_env(reckon_gateway, listen_port),

    Services = #{
        protos => [
            reckon_streams_pb,
            reckon_subscriptions_pb,
            reckon_snapshots_pb,
            reckon_health_pb,
            reckon_temporal_pb,
            reckon_schema_pb,
            reckon_admin_pb,
            reckon_stores_pb,
            reckon_dcb_pb
        ],
        services => #{
            'reckon.gateway.v1.StreamService' =>
                reckon_gateway_stream_service,
            'reckon.gateway.v1.SubscriptionService' =>
                reckon_gateway_subscription_service,
            'reckon.gateway.v1.SnapshotService' =>
                reckon_gateway_snapshot_service,
            'reckon.gateway.v1.HealthService' =>
                reckon_gateway_health_service,
            'reckon.gateway.v1.TemporalService' =>
                reckon_gateway_temporal_service,
            'reckon.gateway.v1.SchemaService' =>
                reckon_gateway_schema_service,
            'reckon.gateway.v1.AdminService' =>
                reckon_gateway_admin_service,
            'reckon.gateway.v1.StoresService' =>
                reckon_gateway_stores_service,
            'reckon.gateway.v1.DcbService' =>
                reckon_gateway_dcb_service
        }
    },

    {ok, _} = grpc:start_server(reckon_gateway_grpc, Port, Services, []),

    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 30
    },
    %% Embedded store mode is opt-in via env. When disabled,
    %% StoreChildren is empty and the gateway runs in pure catalogue
    %% mode (the 0.5 default). When enabled, the starter boots the
    %% local store via reckon_db_sup:start_store/1, and the local
    %% connector publishes its registry entries into the catalogue.
    StoreChildren = case reckon_gateway_config:embedded_store_spec() of
        disabled -> [];
        #{cluster_id := LocalClusterId} ->
            [reckon_gateway_store_starter:child_spec(),
             reckon_gateway_local_connector:child_spec(LocalClusterId)]
    end,
    Children = [
        %% Catalogue first — every connector publishes into it.
        reckon_gateway_catalogue:child_spec(),
        %% Live throughput/latency accumulator (attaches its own
        %% telemetry handler); up before the HTTP/SSE listener reads it.
        reckon_gateway_metrics:child_spec(),
        %% Fleet-wide event-ingest poller (store_stats → events/s).
        reckon_gateway_fleet_ingest:child_spec(),
        %% HTTP/JSON API listener (separate port from gRPC).
        reckon_gateway_http_listener:child_spec(),
        #{id       => clusters_sup,
          start    => {reckon_gateway_clusters_sup, start_link, []},
          restart  => permanent,
          shutdown => 5000,
          type     => supervisor,
          modules  => [reckon_gateway_clusters_sup]}
    ] ++ StoreChildren,
    {ok, {SupFlags, Children}}.
