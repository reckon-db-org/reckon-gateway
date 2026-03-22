%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.TemporalService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_temporal_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpcbox/include/grpcbox.hrl").

-define(is_ctx(Ctx), is_tuple(Ctx) andalso element(1, Ctx) =:= ctx).

-define(SERVICE, 'reckon.gateway.v1.TemporalService').
-define(PROTO_MODULE, 'reckon_temporal_pb').
-define(MARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Input, Output, MessageType), #grpcbox_def{service=?SERVICE,
                                                      message_type=MessageType,
                                                      marshal_fun=?MARSHAL_FUN(Input),
                                                      unmarshal_fun=?UNMARSHAL_FUN(Output)}).

%% @doc Unary RPC
-spec read_until(reckon_temporal_pb:read_until_request()) ->
    {ok, reckon_temporal_pb:read_until_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_until(Input) ->
    read_until(ctx:new(), Input, #{}).

-spec read_until(ctx:t() | reckon_temporal_pb:read_until_request(), reckon_temporal_pb:read_until_request() | grpcbox_client:options()) ->
    {ok, reckon_temporal_pb:read_until_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_until(Ctx, Input) when ?is_ctx(Ctx) ->
    read_until(Ctx, Input, #{});
read_until(Input, Options) ->
    read_until(ctx:new(), Input, Options).

-spec read_until(ctx:t(), reckon_temporal_pb:read_until_request(), grpcbox_client:options()) ->
    {ok, reckon_temporal_pb:read_until_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_until(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.TemporalService/ReadUntil">>, Input, ?DEF(read_until_request, read_until_response, <<"reckon.gateway.v1.ReadUntilRequest">>), Options).

%% @doc Unary RPC
-spec read_range(reckon_temporal_pb:read_range_request()) ->
    {ok, reckon_temporal_pb:read_range_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_range(Input) ->
    read_range(ctx:new(), Input, #{}).

-spec read_range(ctx:t() | reckon_temporal_pb:read_range_request(), reckon_temporal_pb:read_range_request() | grpcbox_client:options()) ->
    {ok, reckon_temporal_pb:read_range_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_range(Ctx, Input) when ?is_ctx(Ctx) ->
    read_range(Ctx, Input, #{});
read_range(Input, Options) ->
    read_range(ctx:new(), Input, Options).

-spec read_range(ctx:t(), reckon_temporal_pb:read_range_request(), grpcbox_client:options()) ->
    {ok, reckon_temporal_pb:read_range_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_range(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.TemporalService/ReadRange">>, Input, ?DEF(read_range_request, read_range_response, <<"reckon.gateway.v1.ReadRangeRequest">>), Options).

%% @doc Unary RPC
-spec version_at(reckon_temporal_pb:version_at_request()) ->
    {ok, reckon_temporal_pb:version_at_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
version_at(Input) ->
    version_at(ctx:new(), Input, #{}).

-spec version_at(ctx:t() | reckon_temporal_pb:version_at_request(), reckon_temporal_pb:version_at_request() | grpcbox_client:options()) ->
    {ok, reckon_temporal_pb:version_at_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
version_at(Ctx, Input) when ?is_ctx(Ctx) ->
    version_at(Ctx, Input, #{});
version_at(Input, Options) ->
    version_at(ctx:new(), Input, Options).

-spec version_at(ctx:t(), reckon_temporal_pb:version_at_request(), grpcbox_client:options()) ->
    {ok, reckon_temporal_pb:version_at_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
version_at(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.TemporalService/VersionAt">>, Input, ?DEF(version_at_request, version_at_response, <<"reckon.gateway.v1.VersionAtRequest">>), Options).

