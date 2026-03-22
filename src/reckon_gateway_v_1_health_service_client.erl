%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.HealthService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_health_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpcbox/include/grpcbox.hrl").

-define(is_ctx(Ctx), is_tuple(Ctx) andalso element(1, Ctx) =:= ctx).

-define(SERVICE, 'reckon.gateway.v1.HealthService').
-define(PROTO_MODULE, 'reckon_health_pb').
-define(MARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Input, Output, MessageType), #grpcbox_def{service=?SERVICE,
                                                      message_type=MessageType,
                                                      marshal_fun=?MARSHAL_FUN(Input),
                                                      unmarshal_fun=?UNMARSHAL_FUN(Output)}).

%% @doc Unary RPC
-spec check(reckon_health_pb:health_check_request()) ->
    {ok, reckon_health_pb:health_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
check(Input) ->
    check(ctx:new(), Input, #{}).

-spec check(ctx:t() | reckon_health_pb:health_check_request(), reckon_health_pb:health_check_request() | grpcbox_client:options()) ->
    {ok, reckon_health_pb:health_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
check(Ctx, Input) when ?is_ctx(Ctx) ->
    check(Ctx, Input, #{});
check(Input, Options) ->
    check(ctx:new(), Input, Options).

-spec check(ctx:t(), reckon_health_pb:health_check_request(), grpcbox_client:options()) ->
    {ok, reckon_health_pb:health_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
check(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.HealthService/Check">>, Input, ?DEF(health_check_request, health_check_response, <<"reckon.gateway.v1.HealthCheckRequest">>), Options).

%% @doc Unary RPC
-spec health(reckon_health_pb:health_request()) ->
    {ok, reckon_health_pb:health_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
health(Input) ->
    health(ctx:new(), Input, #{}).

-spec health(ctx:t() | reckon_health_pb:health_request(), reckon_health_pb:health_request() | grpcbox_client:options()) ->
    {ok, reckon_health_pb:health_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
health(Ctx, Input) when ?is_ctx(Ctx) ->
    health(Ctx, Input, #{});
health(Input, Options) ->
    health(ctx:new(), Input, Options).

-spec health(ctx:t(), reckon_health_pb:health_request(), grpcbox_client:options()) ->
    {ok, reckon_health_pb:health_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
health(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.HealthService/Health">>, Input, ?DEF(health_request, health_response, <<"reckon.gateway.v1.HealthRequest">>), Options).

%% @doc Unary RPC
-spec verify_cluster_consistency(reckon_health_pb:cluster_check_request()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
verify_cluster_consistency(Input) ->
    verify_cluster_consistency(ctx:new(), Input, #{}).

-spec verify_cluster_consistency(ctx:t() | reckon_health_pb:cluster_check_request(), reckon_health_pb:cluster_check_request() | grpcbox_client:options()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
verify_cluster_consistency(Ctx, Input) when ?is_ctx(Ctx) ->
    verify_cluster_consistency(Ctx, Input, #{});
verify_cluster_consistency(Input, Options) ->
    verify_cluster_consistency(ctx:new(), Input, Options).

-spec verify_cluster_consistency(ctx:t(), reckon_health_pb:cluster_check_request(), grpcbox_client:options()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
verify_cluster_consistency(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.HealthService/VerifyClusterConsistency">>, Input, ?DEF(cluster_check_request, cluster_check_response, <<"reckon.gateway.v1.ClusterCheckRequest">>), Options).

%% @doc Unary RPC
-spec verify_membership_consensus(reckon_health_pb:cluster_check_request()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
verify_membership_consensus(Input) ->
    verify_membership_consensus(ctx:new(), Input, #{}).

-spec verify_membership_consensus(ctx:t() | reckon_health_pb:cluster_check_request(), reckon_health_pb:cluster_check_request() | grpcbox_client:options()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
verify_membership_consensus(Ctx, Input) when ?is_ctx(Ctx) ->
    verify_membership_consensus(Ctx, Input, #{});
verify_membership_consensus(Input, Options) ->
    verify_membership_consensus(ctx:new(), Input, Options).

-spec verify_membership_consensus(ctx:t(), reckon_health_pb:cluster_check_request(), grpcbox_client:options()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
verify_membership_consensus(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.HealthService/VerifyMembershipConsensus">>, Input, ?DEF(cluster_check_request, cluster_check_response, <<"reckon.gateway.v1.ClusterCheckRequest">>), Options).

%% @doc Unary RPC
-spec check_raft_log_consistency(reckon_health_pb:cluster_check_request()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
check_raft_log_consistency(Input) ->
    check_raft_log_consistency(ctx:new(), Input, #{}).

-spec check_raft_log_consistency(ctx:t() | reckon_health_pb:cluster_check_request(), reckon_health_pb:cluster_check_request() | grpcbox_client:options()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
check_raft_log_consistency(Ctx, Input) when ?is_ctx(Ctx) ->
    check_raft_log_consistency(Ctx, Input, #{});
check_raft_log_consistency(Input, Options) ->
    check_raft_log_consistency(ctx:new(), Input, Options).

-spec check_raft_log_consistency(ctx:t(), reckon_health_pb:cluster_check_request(), grpcbox_client:options()) ->
    {ok, reckon_health_pb:cluster_check_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
check_raft_log_consistency(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.HealthService/CheckRaftLogConsistency">>, Input, ?DEF(cluster_check_request, cluster_check_response, <<"reckon.gateway.v1.ClusterCheckRequest">>), Options).

%% @doc Unary RPC
-spec get_memory_level(reckon_health_pb:memory_level_request()) ->
    {ok, reckon_health_pb:memory_level_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_memory_level(Input) ->
    get_memory_level(ctx:new(), Input, #{}).

-spec get_memory_level(ctx:t() | reckon_health_pb:memory_level_request(), reckon_health_pb:memory_level_request() | grpcbox_client:options()) ->
    {ok, reckon_health_pb:memory_level_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_memory_level(Ctx, Input) when ?is_ctx(Ctx) ->
    get_memory_level(Ctx, Input, #{});
get_memory_level(Input, Options) ->
    get_memory_level(ctx:new(), Input, Options).

-spec get_memory_level(ctx:t(), reckon_health_pb:memory_level_request(), grpcbox_client:options()) ->
    {ok, reckon_health_pb:memory_level_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_memory_level(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.HealthService/GetMemoryLevel">>, Input, ?DEF(memory_level_request, memory_level_response, <<"reckon.gateway.v1.MemoryLevelRequest">>), Options).

%% @doc Unary RPC
-spec get_memory_stats(reckon_health_pb:memory_stats_request()) ->
    {ok, reckon_health_pb:memory_stats_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_memory_stats(Input) ->
    get_memory_stats(ctx:new(), Input, #{}).

-spec get_memory_stats(ctx:t() | reckon_health_pb:memory_stats_request(), reckon_health_pb:memory_stats_request() | grpcbox_client:options()) ->
    {ok, reckon_health_pb:memory_stats_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_memory_stats(Ctx, Input) when ?is_ctx(Ctx) ->
    get_memory_stats(Ctx, Input, #{});
get_memory_stats(Input, Options) ->
    get_memory_stats(ctx:new(), Input, Options).

-spec get_memory_stats(ctx:t(), reckon_health_pb:memory_stats_request(), grpcbox_client:options()) ->
    {ok, reckon_health_pb:memory_stats_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_memory_stats(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.HealthService/GetMemoryStats">>, Input, ?DEF(memory_stats_request, memory_stats_response, <<"reckon.gateway.v1.MemoryStatsRequest">>), Options).

