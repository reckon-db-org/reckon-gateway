%% @doc Top-level supervisor for the ReckonDB gRPC Gateway.
%%
%% grpcbox configures itself from application env (sys.config).
%% This supervisor exists for future child processes (metrics, etc).
-module(reckon_gateway_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 30
    },
    {ok, {SupFlags, []}}.
