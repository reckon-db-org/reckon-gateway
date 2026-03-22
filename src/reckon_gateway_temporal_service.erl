%% @doc gRPC TemporalService implementation.
-module(reckon_gateway_temporal_service).
-behaviour(reckon_gateway_v_1_temporal_service_bhvr).

-export([read_until/2, read_range/2, version_at/2]).

read_until(Ctx, #{store_id := StoreIdBin,
                  stream_id := StreamId,
                  timestamp := Timestamp,
                  batch_size := BatchSize}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    Opts = case BatchSize of
        0 -> #{};
        BS -> #{batch_size => BS}
    end,
    case esdb_gater_api:read_until(StoreId, StreamId, Timestamp, Opts) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

read_range(Ctx, #{store_id := StoreIdBin,
                  stream_id := StreamId,
                  from_timestamp := From,
                  to_timestamp := To,
                  batch_size := BatchSize}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    Opts = case BatchSize of
        0 -> #{};
        BS -> #{batch_size => BS}
    end,
    case esdb_gater_api:read_range(StoreId, StreamId, From, To, Opts) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

version_at(Ctx, #{store_id := StoreIdBin,
                  stream_id := StreamId,
                  timestamp := Timestamp}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:version_at(StoreId, StreamId, Timestamp) of
        {ok, Version} ->
            {ok, #{version => Version}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
