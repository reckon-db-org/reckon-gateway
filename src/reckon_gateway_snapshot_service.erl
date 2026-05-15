%% @doc gRPC SnapshotService implementation.
-module(reckon_gateway_snapshot_service).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-export([
    record_snapshot/2,
    read_snapshot/2,
    delete_snapshot/2,
    list_snapshots/2,
    list_all_snapshots/2
]).

record_snapshot(#{store_id := StoreIdBin,
                  source_uuid := SourceUuid,
                  stream_uuid := StreamUuid,
                  version := Version,
                  data := Data,
                  metadata := Metadata}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    SnapshotRecord = #{
        data => json:decode(Data),
        metadata => json:decode(Metadata),
        version => Version
    },
    ok = reckon_gater_api:record_snapshot(
        StoreId, SourceUuid, StreamUuid, Version, SnapshotRecord),
    {ok, #{}, Md}.

read_snapshot(#{store_id := StoreIdBin,
                source_uuid := SourceUuid,
                stream_uuid := StreamUuid,
                version := Version}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:read_snapshot(StoreId, SourceUuid, StreamUuid, Version) of
        {ok, Snapshot} ->
            {ok, reckon_gateway_convert:snapshot_to_proto(Snapshot), Md};
        {error, _Reason} ->
            {error, <<"5">>}
    end.

delete_snapshot(#{store_id := StoreIdBin,
                  source_uuid := SourceUuid,
                  stream_uuid := StreamUuid,
                  version := Version}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    ok = reckon_gater_api:delete_snapshot(StoreId, SourceUuid, StreamUuid, Version),
    {ok, #{}, Md}.

list_snapshots(#{store_id := StoreIdBin,
                 source_uuid := SourceUuid,
                 stream_uuid := StreamUuid}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:list_snapshots(StoreId, SourceUuid, StreamUuid) of
        {ok, Snapshots} ->
            ProtoSnapshots = [reckon_gateway_convert:snapshot_to_proto(S) || S <- Snapshots],
            {ok, #{snapshots => ProtoSnapshots}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

list_all_snapshots(#{store_id := StoreIdBin}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case reckon_gater_api:list_all_snapshots(StoreId) of
        {ok, Snapshots} ->
            ProtoSnapshots = [reckon_gateway_convert:snapshot_to_proto(S) || S <- Snapshots],
            {ok, #{snapshots => ProtoSnapshots}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.
