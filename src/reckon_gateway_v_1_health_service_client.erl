%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.HealthService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_health_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.HealthService').
-define(PROTO_MODULE, 'reckon_health_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec check(reckon_health_pb:health_check_request())
    -> {ok, reckon_health_pb:health_check_response(), grpc:metadata()}
     | {error, term()}.
check(Req) ->
    check(Req, #{}, #{}).

-spec check(reckon_health_pb:health_check_request(), grpc:options())
    -> {ok, reckon_health_pb:health_check_response(), grpc:metadata()}
     | {error, term()}.
check(Req, Options) ->
    check(Req, #{}, Options).

-spec check(reckon_health_pb:health_check_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_health_pb:health_check_response(), grpc:metadata()}
     | {error, term()}.
check(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.HealthService/Check">>,
                           health_check_request, health_check_response, <<"reckon.gateway.v1.HealthCheckRequest">>),
                      Req, Metadata, Options).

-spec health(reckon_health_pb:health_request())
    -> {ok, reckon_health_pb:health_response(), grpc:metadata()}
     | {error, term()}.
health(Req) ->
    health(Req, #{}, #{}).

-spec health(reckon_health_pb:health_request(), grpc:options())
    -> {ok, reckon_health_pb:health_response(), grpc:metadata()}
     | {error, term()}.
health(Req, Options) ->
    health(Req, #{}, Options).

-spec health(reckon_health_pb:health_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_health_pb:health_response(), grpc:metadata()}
     | {error, term()}.
health(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.HealthService/Health">>,
                           health_request, health_response, <<"reckon.gateway.v1.HealthRequest">>),
                      Req, Metadata, Options).

-spec verify_cluster_consistency(reckon_health_pb:cluster_check_request())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
verify_cluster_consistency(Req) ->
    verify_cluster_consistency(Req, #{}, #{}).

-spec verify_cluster_consistency(reckon_health_pb:cluster_check_request(), grpc:options())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
verify_cluster_consistency(Req, Options) ->
    verify_cluster_consistency(Req, #{}, Options).

-spec verify_cluster_consistency(reckon_health_pb:cluster_check_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
verify_cluster_consistency(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.HealthService/VerifyClusterConsistency">>,
                           cluster_check_request, cluster_check_response, <<"reckon.gateway.v1.ClusterCheckRequest">>),
                      Req, Metadata, Options).

-spec verify_membership_consensus(reckon_health_pb:cluster_check_request())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
verify_membership_consensus(Req) ->
    verify_membership_consensus(Req, #{}, #{}).

-spec verify_membership_consensus(reckon_health_pb:cluster_check_request(), grpc:options())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
verify_membership_consensus(Req, Options) ->
    verify_membership_consensus(Req, #{}, Options).

-spec verify_membership_consensus(reckon_health_pb:cluster_check_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
verify_membership_consensus(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.HealthService/VerifyMembershipConsensus">>,
                           cluster_check_request, cluster_check_response, <<"reckon.gateway.v1.ClusterCheckRequest">>),
                      Req, Metadata, Options).

-spec check_raft_log_consistency(reckon_health_pb:cluster_check_request())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
check_raft_log_consistency(Req) ->
    check_raft_log_consistency(Req, #{}, #{}).

-spec check_raft_log_consistency(reckon_health_pb:cluster_check_request(), grpc:options())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
check_raft_log_consistency(Req, Options) ->
    check_raft_log_consistency(Req, #{}, Options).

-spec check_raft_log_consistency(reckon_health_pb:cluster_check_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_health_pb:cluster_check_response(), grpc:metadata()}
     | {error, term()}.
check_raft_log_consistency(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.HealthService/CheckRaftLogConsistency">>,
                           cluster_check_request, cluster_check_response, <<"reckon.gateway.v1.ClusterCheckRequest">>),
                      Req, Metadata, Options).

-spec get_memory_level(reckon_health_pb:memory_level_request())
    -> {ok, reckon_health_pb:memory_level_response(), grpc:metadata()}
     | {error, term()}.
get_memory_level(Req) ->
    get_memory_level(Req, #{}, #{}).

-spec get_memory_level(reckon_health_pb:memory_level_request(), grpc:options())
    -> {ok, reckon_health_pb:memory_level_response(), grpc:metadata()}
     | {error, term()}.
get_memory_level(Req, Options) ->
    get_memory_level(Req, #{}, Options).

-spec get_memory_level(reckon_health_pb:memory_level_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_health_pb:memory_level_response(), grpc:metadata()}
     | {error, term()}.
get_memory_level(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.HealthService/GetMemoryLevel">>,
                           memory_level_request, memory_level_response, <<"reckon.gateway.v1.MemoryLevelRequest">>),
                      Req, Metadata, Options).

-spec get_memory_stats(reckon_health_pb:memory_stats_request())
    -> {ok, reckon_health_pb:memory_stats_response(), grpc:metadata()}
     | {error, term()}.
get_memory_stats(Req) ->
    get_memory_stats(Req, #{}, #{}).

-spec get_memory_stats(reckon_health_pb:memory_stats_request(), grpc:options())
    -> {ok, reckon_health_pb:memory_stats_response(), grpc:metadata()}
     | {error, term()}.
get_memory_stats(Req, Options) ->
    get_memory_stats(Req, #{}, Options).

-spec get_memory_stats(reckon_health_pb:memory_stats_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_health_pb:memory_stats_response(), grpc:metadata()}
     | {error, term()}.
get_memory_stats(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.HealthService/GetMemoryStats">>,
                           memory_stats_request, memory_stats_response, <<"reckon.gateway.v1.MemoryStatsRequest">>),
                      Req, Metadata, Options).

-spec get_server_info(reckon_health_pb:get_server_info_request())
    -> {ok, reckon_health_pb:server_info_response(), grpc:metadata()}
     | {error, term()}.
get_server_info(Req) ->
    get_server_info(Req, #{}, #{}).

-spec get_server_info(reckon_health_pb:get_server_info_request(), grpc:options())
    -> {ok, reckon_health_pb:server_info_response(), grpc:metadata()}
     | {error, term()}.
get_server_info(Req, Options) ->
    get_server_info(Req, #{}, Options).

-spec get_server_info(reckon_health_pb:get_server_info_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_health_pb:server_info_response(), grpc:metadata()}
     | {error, term()}.
get_server_info(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.HealthService/GetServerInfo">>,
                           get_server_info_request, server_info_response, <<"reckon.gateway.v1.GetServerInfoRequest">>),
                      Req, Metadata, Options).

