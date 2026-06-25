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
    with_store_id(StoreIdBin, read_snapshot,
        fun(StoreId) ->
            read_snapshot_reply(
                reckon_gateway_dispatch:call(read_snapshot,
                    [StoreId, SourceUuid, StreamUuid, Version]), Md)
        end).

read_snapshot_reply({ok, Snapshot}, Md) ->
    {ok, reckon_gateway_convert:snapshot_to_proto(Snapshot), Md};
read_snapshot_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(read_snapshot, <<"5">>, Reason).

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
    with_store_id(StoreIdBin, list_snapshots,
        fun(StoreId) ->
            snapshots_reply(
                reckon_gateway_dispatch:call(list_snapshots, [StoreId, SourceUuid, StreamUuid]),
                list_snapshots, Md)
        end).

list_all_snapshots(#{store_id := StoreIdBin}, Md) ->
    with_store_id(StoreIdBin, list_all_snapshots,
        fun(StoreId) ->
            snapshots_reply(reckon_gateway_dispatch:call(list_all_snapshots, [StoreId]),
                            list_all_snapshots, Md)
        end).

%% @private Shared snapshots-list reply.
snapshots_reply({ok, Snapshots}, _Op, Md) ->
    {ok, #{snapshots => [reckon_gateway_convert:snapshot_to_proto(S) || S <- Snapshots]}, Md};
snapshots_reply({error, Reason}, Op, _Md) ->
    reckon_gateway_error:wrap(Op, <<"13">>, Reason).

%%====================================================================
%% Internal
%%====================================================================

%% @private Resolve a store-id binary, wrapping the canonical
%% invalid_store_id gRPC error, then run Fun with the parsed id.
with_store_id(StoreIdBin, ErrFn, Fun) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(ErrFn, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            Fun(StoreId)
    end.
