%% @doc gRPC SnapshotService implementation.
-module(reckon_gateway_snapshot_service).
-behaviour(reckon_gateway_v_1_snapshot_service_bhvr).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-export([
    record_snapshot/2,
    read_snapshot/2,
    delete_snapshot/2,
    list_snapshots/2,
    list_all_snapshots/2
]).

record_snapshot(Ctx, #{store_id := StoreIdBin,
                       source_uuid := SourceUuid,
                       stream_uuid := StreamUuid,
                       version := Version,
                       data := Data,
                       metadata := Metadata}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SnapshotRecord = #{
        data => json:decode(Data),
        metadata => json:decode(Metadata),
        version => Version
    },
    ok = esdb_gater_api:record_snapshot(
        StoreId, SourceUuid, StreamUuid, Version, SnapshotRecord),
    {ok, #{}, Ctx}.

read_snapshot(Ctx, #{store_id := StoreIdBin,
                     source_uuid := SourceUuid,
                     stream_uuid := StreamUuid,
                     version := Version}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:read_snapshot(StoreId, SourceUuid, StreamUuid, Version) of
        {ok, Snapshot} ->
            {ok, reckon_gateway_convert:snapshot_to_proto(Snapshot), Ctx};
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

delete_snapshot(Ctx, #{store_id := StoreIdBin,
                       source_uuid := SourceUuid,
                       stream_uuid := StreamUuid,
                       version := Version}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    ok = esdb_gater_api:delete_snapshot(StoreId, SourceUuid, StreamUuid, Version),
    {ok, #{}, Ctx}.

list_snapshots(Ctx, #{store_id := StoreIdBin,
                      source_uuid := SourceUuid,
                      stream_uuid := StreamUuid}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:list_snapshots(StoreId, SourceUuid, StreamUuid) of
        {ok, Snapshots} ->
            ProtoSnapshots = [reckon_gateway_convert:snapshot_to_proto(S) || S <- Snapshots],
            {ok, #{snapshots => ProtoSnapshots}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

list_all_snapshots(Ctx, #{store_id := StoreIdBin}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:list_all_snapshots(StoreId) of
        {ok, Snapshots} ->
            ProtoSnapshots = [reckon_gateway_convert:snapshot_to_proto(S) || S <- Snapshots],
            {ok, #{snapshots => ProtoSnapshots}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
