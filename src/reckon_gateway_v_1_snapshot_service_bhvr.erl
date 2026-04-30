%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.SnapshotService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_snapshot_service_bhvr).

-callback record_snapshot(reckon_snapshots_pb:record_snapshot_request(), grpc:metadata())
    -> {ok, reckon_snapshots_pb:record_snapshot_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback read_snapshot(reckon_snapshots_pb:read_snapshot_request(), grpc:metadata())
    -> {ok, reckon_snapshots_pb:snapshot_record(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback delete_snapshot(reckon_snapshots_pb:delete_snapshot_request(), grpc:metadata())
    -> {ok, reckon_snapshots_pb:delete_snapshot_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback list_snapshots(reckon_snapshots_pb:list_snapshots_request(), grpc:metadata())
    -> {ok, reckon_snapshots_pb:list_snapshots_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback list_all_snapshots(reckon_snapshots_pb:list_all_snapshots_request(), grpc:metadata())
    -> {ok, reckon_snapshots_pb:list_snapshots_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

