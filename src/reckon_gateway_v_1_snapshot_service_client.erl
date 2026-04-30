%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.SnapshotService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_snapshot_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.SnapshotService').
-define(PROTO_MODULE, 'reckon_snapshots_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec record_snapshot(reckon_snapshots_pb:record_snapshot_request())
    -> {ok, reckon_snapshots_pb:record_snapshot_response(), grpc:metadata()}
     | {error, term()}.
record_snapshot(Req) ->
    record_snapshot(Req, #{}, #{}).

-spec record_snapshot(reckon_snapshots_pb:record_snapshot_request(), grpc:options())
    -> {ok, reckon_snapshots_pb:record_snapshot_response(), grpc:metadata()}
     | {error, term()}.
record_snapshot(Req, Options) ->
    record_snapshot(Req, #{}, Options).

-spec record_snapshot(reckon_snapshots_pb:record_snapshot_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_snapshots_pb:record_snapshot_response(), grpc:metadata()}
     | {error, term()}.
record_snapshot(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SnapshotService/RecordSnapshot">>,
                           record_snapshot_request, record_snapshot_response, <<"reckon.gateway.v1.RecordSnapshotRequest">>),
                      Req, Metadata, Options).

-spec read_snapshot(reckon_snapshots_pb:read_snapshot_request())
    -> {ok, reckon_snapshots_pb:snapshot_record(), grpc:metadata()}
     | {error, term()}.
read_snapshot(Req) ->
    read_snapshot(Req, #{}, #{}).

-spec read_snapshot(reckon_snapshots_pb:read_snapshot_request(), grpc:options())
    -> {ok, reckon_snapshots_pb:snapshot_record(), grpc:metadata()}
     | {error, term()}.
read_snapshot(Req, Options) ->
    read_snapshot(Req, #{}, Options).

-spec read_snapshot(reckon_snapshots_pb:read_snapshot_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_snapshots_pb:snapshot_record(), grpc:metadata()}
     | {error, term()}.
read_snapshot(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SnapshotService/ReadSnapshot">>,
                           read_snapshot_request, snapshot_record, <<"reckon.gateway.v1.ReadSnapshotRequest">>),
                      Req, Metadata, Options).

-spec delete_snapshot(reckon_snapshots_pb:delete_snapshot_request())
    -> {ok, reckon_snapshots_pb:delete_snapshot_response(), grpc:metadata()}
     | {error, term()}.
delete_snapshot(Req) ->
    delete_snapshot(Req, #{}, #{}).

-spec delete_snapshot(reckon_snapshots_pb:delete_snapshot_request(), grpc:options())
    -> {ok, reckon_snapshots_pb:delete_snapshot_response(), grpc:metadata()}
     | {error, term()}.
delete_snapshot(Req, Options) ->
    delete_snapshot(Req, #{}, Options).

-spec delete_snapshot(reckon_snapshots_pb:delete_snapshot_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_snapshots_pb:delete_snapshot_response(), grpc:metadata()}
     | {error, term()}.
delete_snapshot(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SnapshotService/DeleteSnapshot">>,
                           delete_snapshot_request, delete_snapshot_response, <<"reckon.gateway.v1.DeleteSnapshotRequest">>),
                      Req, Metadata, Options).

-spec list_snapshots(reckon_snapshots_pb:list_snapshots_request())
    -> {ok, reckon_snapshots_pb:list_snapshots_response(), grpc:metadata()}
     | {error, term()}.
list_snapshots(Req) ->
    list_snapshots(Req, #{}, #{}).

-spec list_snapshots(reckon_snapshots_pb:list_snapshots_request(), grpc:options())
    -> {ok, reckon_snapshots_pb:list_snapshots_response(), grpc:metadata()}
     | {error, term()}.
list_snapshots(Req, Options) ->
    list_snapshots(Req, #{}, Options).

-spec list_snapshots(reckon_snapshots_pb:list_snapshots_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_snapshots_pb:list_snapshots_response(), grpc:metadata()}
     | {error, term()}.
list_snapshots(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SnapshotService/ListSnapshots">>,
                           list_snapshots_request, list_snapshots_response, <<"reckon.gateway.v1.ListSnapshotsRequest">>),
                      Req, Metadata, Options).

-spec list_all_snapshots(reckon_snapshots_pb:list_all_snapshots_request())
    -> {ok, reckon_snapshots_pb:list_snapshots_response(), grpc:metadata()}
     | {error, term()}.
list_all_snapshots(Req) ->
    list_all_snapshots(Req, #{}, #{}).

-spec list_all_snapshots(reckon_snapshots_pb:list_all_snapshots_request(), grpc:options())
    -> {ok, reckon_snapshots_pb:list_snapshots_response(), grpc:metadata()}
     | {error, term()}.
list_all_snapshots(Req, Options) ->
    list_all_snapshots(Req, #{}, Options).

-spec list_all_snapshots(reckon_snapshots_pb:list_all_snapshots_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_snapshots_pb:list_snapshots_response(), grpc:metadata()}
     | {error, term()}.
list_all_snapshots(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.SnapshotService/ListAllSnapshots">>,
                           list_all_snapshots_request, list_snapshots_response, <<"reckon.gateway.v1.ListAllSnapshotsRequest">>),
                      Req, Metadata, Options).

