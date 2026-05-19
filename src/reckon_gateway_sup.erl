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
            reckon_causation_pb,
            reckon_schema_pb,
            reckon_admin_pb,
            reckon_stores_pb
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
            'reckon.gateway.v1.CausationService' =>
                reckon_gateway_causation_service,
            'reckon.gateway.v1.SchemaService' =>
                reckon_gateway_schema_service,
            'reckon.gateway.v1.AdminService' =>
                reckon_gateway_admin_service,
            'reckon.gateway.v1.StoresService' =>
                reckon_gateway_stores_service
        }
    },

    {ok, _} = grpc:start_server(reckon_gateway_grpc, Port, Services, []),

    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 30
    },
    Children = [
        %% Catalogue first — connectors publish into it.
        reckon_gateway_catalogue:child_spec(),
        #{id       => clusters_sup,
          start    => {reckon_gateway_clusters_sup, start_link, []},
          restart  => permanent,
          shutdown => 5000,
          type     => supervisor,
          modules  => [reckon_gateway_clusters_sup]}
    ],
    {ok, {SupFlags, Children}}.
