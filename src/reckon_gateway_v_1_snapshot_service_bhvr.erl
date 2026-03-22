%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.SnapshotService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_snapshot_service_bhvr).

%% Unary RPC
-callback record_snapshot(ctx:t(), reckon_snapshots_pb:record_snapshot_request()) ->
    {ok, reckon_snapshots_pb:record_snapshot_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback read_snapshot(ctx:t(), reckon_snapshots_pb:read_snapshot_request()) ->
    {ok, reckon_snapshots_pb:snapshot_record(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback delete_snapshot(ctx:t(), reckon_snapshots_pb:delete_snapshot_request()) ->
    {ok, reckon_snapshots_pb:delete_snapshot_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback list_snapshots(ctx:t(), reckon_snapshots_pb:list_snapshots_request()) ->
    {ok, reckon_snapshots_pb:list_snapshots_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback list_all_snapshots(ctx:t(), reckon_snapshots_pb:list_all_snapshots_request()) ->
    {ok, reckon_snapshots_pb:list_snapshots_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

