%% @doc gRPC TemporalService implementation.
%%
%% Error paths routed through reckon_gateway_error so the
%% underlying reason is logged server-side (grpc-erl drops
%% grpc-message on unary; see reckon_gateway_error docstring).
-module(reckon_gateway_temporal_service).

-export([read_until/2, read_range/2, version_at/2]).

read_until(#{store_id := StoreIdBin,
             stream_id := StreamId,
             timestamp := Timestamp,
             batch_size := BatchSize}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(read_until, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            Opts = case BatchSize of
                0 -> #{};
                BS -> #{batch_size => BS}
            end,
            case reckon_gateway_dispatch:call(read_until, [StoreId, StreamId, Timestamp, Opts]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(read_until, <<"13">>, Reason)
            end
    end.

read_range(#{store_id := StoreIdBin,
             stream_id := StreamId,
             from_timestamp := From,
             to_timestamp := To,
             batch_size := BatchSize}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(read_range, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            Opts = case BatchSize of
                0 -> #{};
                BS -> #{batch_size => BS}
            end,
            case reckon_gateway_dispatch:call(read_range, [StoreId, StreamId, From, To, Opts]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(read_range, <<"13">>, Reason)
            end
    end.

version_at(#{store_id := StoreIdBin,
             stream_id := StreamId,
             timestamp := Timestamp}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(version_at, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(version_at, [StoreId, StreamId, Timestamp]) of
                {ok, Version} ->
                    {ok, #{version => Version}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(version_at, <<"13">>, Reason)
            end
    end.
