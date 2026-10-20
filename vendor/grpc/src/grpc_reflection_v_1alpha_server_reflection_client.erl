%%%-------------------------------------------------------------------
%% @doc Client module for grpc service grpc.reflection.v1alpha.ServerReflection.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(grpc_reflection_v_1alpha_server_reflection_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'grpc.reflection.v1alpha.ServerReflection').
-define(PROTO_MODULE, 'grpc_reflection_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec server_reflection_info(grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
server_reflection_info(Options) ->
    server_reflection_info(#{}, Options).

-spec server_reflection_info(grpc:metadata(), grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
server_reflection_info(Metadata, Options) ->
    grpc_client:open(?DEF(<<"/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo">>,
                          server_reflection_request, server_reflection_response, <<"grpc.reflection.v1alpha.ServerReflectionRequest">>),
                     Metadata, Options).

