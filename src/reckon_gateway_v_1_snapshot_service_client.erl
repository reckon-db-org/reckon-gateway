%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.SnapshotService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_snapshot_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpcbox/include/grpcbox.hrl").

-define(is_ctx(Ctx), is_tuple(Ctx) andalso element(1, Ctx) =:= ctx).

-define(SERVICE, 'reckon.gateway.v1.SnapshotService').
-define(PROTO_MODULE, 'reckon_snapshots_pb').
-define(MARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Input, Output, MessageType), #grpcbox_def{service=?SERVICE,
                                                      message_type=MessageType,
                                                      marshal_fun=?MARSHAL_FUN(Input),
                                                      unmarshal_fun=?UNMARSHAL_FUN(Output)}).

%% @doc Unary RPC
-spec record_snapshot(reckon_snapshots_pb:record_snapshot_request()) ->
    {ok, reckon_snapshots_pb:record_snapshot_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
record_snapshot(Input) ->
    record_snapshot(ctx:new(), Input, #{}).

-spec record_snapshot(ctx:t() | reckon_snapshots_pb:record_snapshot_request(), reckon_snapshots_pb:record_snapshot_request() | grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:record_snapshot_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
record_snapshot(Ctx, Input) when ?is_ctx(Ctx) ->
    record_snapshot(Ctx, Input, #{});
record_snapshot(Input, Options) ->
    record_snapshot(ctx:new(), Input, Options).

-spec record_snapshot(ctx:t(), reckon_snapshots_pb:record_snapshot_request(), grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:record_snapshot_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
record_snapshot(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SnapshotService/RecordSnapshot">>, Input, ?DEF(record_snapshot_request, record_snapshot_response, <<"reckon.gateway.v1.RecordSnapshotRequest">>), Options).

%% @doc Unary RPC
-spec read_snapshot(reckon_snapshots_pb:read_snapshot_request()) ->
    {ok, reckon_snapshots_pb:snapshot_record(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_snapshot(Input) ->
    read_snapshot(ctx:new(), Input, #{}).

-spec read_snapshot(ctx:t() | reckon_snapshots_pb:read_snapshot_request(), reckon_snapshots_pb:read_snapshot_request() | grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:snapshot_record(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_snapshot(Ctx, Input) when ?is_ctx(Ctx) ->
    read_snapshot(Ctx, Input, #{});
read_snapshot(Input, Options) ->
    read_snapshot(ctx:new(), Input, Options).

-spec read_snapshot(ctx:t(), reckon_snapshots_pb:read_snapshot_request(), grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:snapshot_record(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_snapshot(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SnapshotService/ReadSnapshot">>, Input, ?DEF(read_snapshot_request, snapshot_record, <<"reckon.gateway.v1.ReadSnapshotRequest">>), Options).

%% @doc Unary RPC
-spec delete_snapshot(reckon_snapshots_pb:delete_snapshot_request()) ->
    {ok, reckon_snapshots_pb:delete_snapshot_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_snapshot(Input) ->
    delete_snapshot(ctx:new(), Input, #{}).

-spec delete_snapshot(ctx:t() | reckon_snapshots_pb:delete_snapshot_request(), reckon_snapshots_pb:delete_snapshot_request() | grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:delete_snapshot_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_snapshot(Ctx, Input) when ?is_ctx(Ctx) ->
    delete_snapshot(Ctx, Input, #{});
delete_snapshot(Input, Options) ->
    delete_snapshot(ctx:new(), Input, Options).

-spec delete_snapshot(ctx:t(), reckon_snapshots_pb:delete_snapshot_request(), grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:delete_snapshot_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_snapshot(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SnapshotService/DeleteSnapshot">>, Input, ?DEF(delete_snapshot_request, delete_snapshot_response, <<"reckon.gateway.v1.DeleteSnapshotRequest">>), Options).

%% @doc Unary RPC
-spec list_snapshots(reckon_snapshots_pb:list_snapshots_request()) ->
    {ok, reckon_snapshots_pb:list_snapshots_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_snapshots(Input) ->
    list_snapshots(ctx:new(), Input, #{}).

-spec list_snapshots(ctx:t() | reckon_snapshots_pb:list_snapshots_request(), reckon_snapshots_pb:list_snapshots_request() | grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:list_snapshots_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_snapshots(Ctx, Input) when ?is_ctx(Ctx) ->
    list_snapshots(Ctx, Input, #{});
list_snapshots(Input, Options) ->
    list_snapshots(ctx:new(), Input, Options).

-spec list_snapshots(ctx:t(), reckon_snapshots_pb:list_snapshots_request(), grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:list_snapshots_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_snapshots(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SnapshotService/ListSnapshots">>, Input, ?DEF(list_snapshots_request, list_snapshots_response, <<"reckon.gateway.v1.ListSnapshotsRequest">>), Options).

%% @doc Unary RPC
-spec list_all_snapshots(reckon_snapshots_pb:list_all_snapshots_request()) ->
    {ok, reckon_snapshots_pb:list_snapshots_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_all_snapshots(Input) ->
    list_all_snapshots(ctx:new(), Input, #{}).

-spec list_all_snapshots(ctx:t() | reckon_snapshots_pb:list_all_snapshots_request(), reckon_snapshots_pb:list_all_snapshots_request() | grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:list_snapshots_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_all_snapshots(Ctx, Input) when ?is_ctx(Ctx) ->
    list_all_snapshots(Ctx, Input, #{});
list_all_snapshots(Input, Options) ->
    list_all_snapshots(ctx:new(), Input, Options).

-spec list_all_snapshots(ctx:t(), reckon_snapshots_pb:list_all_snapshots_request(), grpcbox_client:options()) ->
    {ok, reckon_snapshots_pb:list_snapshots_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_all_snapshots(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.SnapshotService/ListAllSnapshots">>, Input, ?DEF(list_all_snapshots_request, list_snapshots_response, <<"reckon.gateway.v1.ListAllSnapshotsRequest">>), Options).

