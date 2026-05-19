%% @doc gRPC TemporalService implementation.
-module(reckon_gateway_temporal_service).

-export([read_until/2, read_range/2, version_at/2]).

read_until(#{store_id := StoreIdBin,
             stream_id := StreamId,
             timestamp := Timestamp,
             batch_size := BatchSize}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            Opts = case BatchSize of
                0 -> #{};
                BS -> #{batch_size => BS}
            end,
            case reckon_gateway_dispatch:call(read_until, [StoreId, StreamId, Timestamp, Opts]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, _Reason} ->
                    {error, <<"13">>}
            end
    end.

read_range(#{store_id := StoreIdBin,
             stream_id := StreamId,
             from_timestamp := From,
             to_timestamp := To,
             batch_size := BatchSize}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            Opts = case BatchSize of
                0 -> #{};
                BS -> #{batch_size => BS}
            end,
            case reckon_gateway_dispatch:call(read_range, [StoreId, StreamId, From, To, Opts]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, _Reason} ->
                    {error, <<"13">>}
            end
    end.

version_at(#{store_id := StoreIdBin,
             stream_id := StreamId,
             timestamp := Timestamp}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(version_at, [StoreId, StreamId, Timestamp]) of
                {ok, Version} ->
                    {ok, #{version => Version}, Md};
                {error, _Reason} ->
                    {error, <<"13">>}
            end
    end.
