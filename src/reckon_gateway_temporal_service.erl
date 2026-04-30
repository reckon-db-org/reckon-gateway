%% @doc gRPC TemporalService implementation.
-module(reckon_gateway_temporal_service).

-export([read_until/2, read_range/2, version_at/2]).

read_until(#{store_id := StoreIdBin,
             stream_id := StreamId,
             timestamp := Timestamp,
             batch_size := BatchSize}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    Opts = case BatchSize of
        0 -> #{};
        BS -> #{batch_size => BS}
    end,
    case esdb_gater_api:read_until(StoreId, StreamId, Timestamp, Opts) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

read_range(#{store_id := StoreIdBin,
             stream_id := StreamId,
             from_timestamp := From,
             to_timestamp := To,
             batch_size := BatchSize}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    Opts = case BatchSize of
        0 -> #{};
        BS -> #{batch_size => BS}
    end,
    case esdb_gater_api:read_range(StoreId, StreamId, From, To, Opts) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

version_at(#{store_id := StoreIdBin,
             stream_id := StreamId,
             timestamp := Timestamp}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:version_at(StoreId, StreamId, Timestamp) of
        {ok, Version} ->
            {ok, #{version => Version}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.
