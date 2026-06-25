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
    with_store_id(StoreIdBin, read_until,
        fun(StoreId) ->
            recorded_reply(
                reckon_gateway_dispatch:call(read_until,
                    [StoreId, StreamId, Timestamp, batch_opts(BatchSize)]),
                read_until, Md)
        end).

read_range(#{store_id := StoreIdBin,
             stream_id := StreamId,
             from_timestamp := From,
             to_timestamp := To,
             batch_size := BatchSize}, Md) ->
    with_store_id(StoreIdBin, read_range,
        fun(StoreId) ->
            recorded_reply(
                reckon_gateway_dispatch:call(read_range,
                    [StoreId, StreamId, From, To, batch_opts(BatchSize)]),
                read_range, Md)
        end).

version_at(#{store_id := StoreIdBin,
             stream_id := StreamId,
             timestamp := Timestamp}, Md) ->
    with_store_id(StoreIdBin, version_at,
        fun(StoreId) ->
            version_reply(
                reckon_gateway_dispatch:call(version_at, [StoreId, StreamId, Timestamp]), Md)
        end).

version_reply({ok, Version}, Md) ->
    {ok, #{version => Version}, Md};
version_reply({error, Reason}, _Md) ->
    reckon_gateway_error:wrap(version_at, <<"13">>, Reason).

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

batch_opts(0)  -> #{};
batch_opts(BS) -> #{batch_size => BS}.

%% @private Map a dispatch result of recorded events to the proto
%% reply, or wrap the error (code 13) under ErrFn.
recorded_reply({ok, Events}, _ErrFn, Md) ->
    {ok, #{events => [reckon_gateway_convert:event_to_recorded(E) || E <- Events]}, Md};
recorded_reply({error, Reason}, ErrFn, _Md) ->
    reckon_gateway_error:wrap(ErrFn, <<"13">>, Reason).
