%% @doc gRPC SnapshotService implementation.
%%
%% Error paths routed through reckon_gateway_error so the
%% underlying reason is logged server-side (grpc-erl drops
%% grpc-message on unary; see reckon_gateway_error docstring).
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
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(record_snapshot, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            SnapshotRecord = #{
                data => json:decode(Data),
                metadata => json:decode(Metadata),
                version => Version
            },
            ok = reckon_gateway_dispatch:call(record_snapshot, [
                StoreId, SourceUuid, StreamUuid, Version, SnapshotRecord]),
            {ok, #{}, Md}
    end.

read_snapshot(#{store_id := StoreIdBin,
                source_uuid := SourceUuid,
                stream_uuid := StreamUuid,
                version := Version}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(read_snapshot, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(read_snapshot, [StoreId, SourceUuid, StreamUuid, Version]) of
                {ok, Snapshot} ->
                    {ok, reckon_gateway_convert:snapshot_to_proto(Snapshot), Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(read_snapshot, <<"5">>, Reason)
            end
    end.

delete_snapshot(#{store_id := StoreIdBin,
                  source_uuid := SourceUuid,
                  stream_uuid := StreamUuid,
                  version := Version}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(delete_snapshot, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            ok = reckon_gateway_dispatch:call(delete_snapshot, [StoreId, SourceUuid, StreamUuid, Version]),
            {ok, #{}, Md}
    end.

list_snapshots(#{store_id := StoreIdBin,
                 source_uuid := SourceUuid,
                 stream_uuid := StreamUuid}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(list_snapshots, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(list_snapshots, [StoreId, SourceUuid, StreamUuid]) of
                {ok, Snapshots} ->
                    ProtoSnapshots = [reckon_gateway_convert:snapshot_to_proto(S) || S <- Snapshots],
                    {ok, #{snapshots => ProtoSnapshots}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(list_snapshots, <<"13">>, Reason)
            end
    end.

list_all_snapshots(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(list_all_snapshots, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(list_all_snapshots, [StoreId]) of
                {ok, Snapshots} ->
                    ProtoSnapshots = [reckon_gateway_convert:snapshot_to_proto(S) || S <- Snapshots],
                    {ok, #{snapshots => ProtoSnapshots}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(list_all_snapshots, <<"13">>, Reason)
            end
    end.
