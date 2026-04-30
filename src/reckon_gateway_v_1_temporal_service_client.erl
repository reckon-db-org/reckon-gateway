%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.TemporalService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_temporal_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.TemporalService').
-define(PROTO_MODULE, 'reckon_temporal_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec read_until(reckon_temporal_pb:read_until_request())
    -> {ok, reckon_temporal_pb:read_until_response(), grpc:metadata()}
     | {error, term()}.
read_until(Req) ->
    read_until(Req, #{}, #{}).

-spec read_until(reckon_temporal_pb:read_until_request(), grpc:options())
    -> {ok, reckon_temporal_pb:read_until_response(), grpc:metadata()}
     | {error, term()}.
read_until(Req, Options) ->
    read_until(Req, #{}, Options).

-spec read_until(reckon_temporal_pb:read_until_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_temporal_pb:read_until_response(), grpc:metadata()}
     | {error, term()}.
read_until(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.TemporalService/ReadUntil">>,
                           read_until_request, read_until_response, <<"reckon.gateway.v1.ReadUntilRequest">>),
                      Req, Metadata, Options).

-spec read_range(reckon_temporal_pb:read_range_request())
    -> {ok, reckon_temporal_pb:read_range_response(), grpc:metadata()}
     | {error, term()}.
read_range(Req) ->
    read_range(Req, #{}, #{}).

-spec read_range(reckon_temporal_pb:read_range_request(), grpc:options())
    -> {ok, reckon_temporal_pb:read_range_response(), grpc:metadata()}
     | {error, term()}.
read_range(Req, Options) ->
    read_range(Req, #{}, Options).

-spec read_range(reckon_temporal_pb:read_range_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_temporal_pb:read_range_response(), grpc:metadata()}
     | {error, term()}.
read_range(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.TemporalService/ReadRange">>,
                           read_range_request, read_range_response, <<"reckon.gateway.v1.ReadRangeRequest">>),
                      Req, Metadata, Options).

-spec version_at(reckon_temporal_pb:version_at_request())
    -> {ok, reckon_temporal_pb:version_at_response(), grpc:metadata()}
     | {error, term()}.
version_at(Req) ->
    version_at(Req, #{}, #{}).

-spec version_at(reckon_temporal_pb:version_at_request(), grpc:options())
    -> {ok, reckon_temporal_pb:version_at_response(), grpc:metadata()}
     | {error, term()}.
version_at(Req, Options) ->
    version_at(Req, #{}, Options).

-spec version_at(reckon_temporal_pb:version_at_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_temporal_pb:version_at_response(), grpc:metadata()}
     | {error, term()}.
version_at(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.TemporalService/VersionAt">>,
                           version_at_request, version_at_response, <<"reckon.gateway.v1.VersionAtRequest">>),
                      Req, Metadata, Options).

