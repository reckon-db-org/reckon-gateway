%%%-------------------------------------------------------------------
%% @doc Client module for grpc service grpc.health.v1.Health.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(grpc_health_v_1_health_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'grpc.health.v1.Health').
-define(PROTO_MODULE, 'grpc_health_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec check(grpc_health_pb:health_check_request())
    -> {ok, grpc_health_pb:health_check_response(), grpc:metadata()}
     | {error, term()}.
check(Req) ->
    check(Req, #{}, #{}).

-spec check(grpc_health_pb:health_check_request(), grpc:options())
    -> {ok, grpc_health_pb:health_check_response(), grpc:metadata()}
     | {error, term()}.
check(Req, Options) ->
    check(Req, #{}, Options).

-spec check(grpc_health_pb:health_check_request(), grpc:metadata(), grpc_client:options())
    -> {ok, grpc_health_pb:health_check_response(), grpc:metadata()}
     | {error, term()}.
check(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/grpc.health.v1.Health/Check">>,
                           health_check_request, health_check_response, <<"grpc.health.v1.HealthCheckRequest">>),
                      Req, Metadata, Options).

-spec watch(grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
watch(Options) ->
    watch(#{}, Options).

-spec watch(grpc:metadata(), grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
watch(Metadata, Options) ->
    grpc_client:open(?DEF(<<"/grpc.health.v1.Health/Watch">>,
                          health_check_request, health_check_response, <<"grpc.health.v1.HealthCheckRequest">>),
                     Metadata, Options).

