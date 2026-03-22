%% @doc Conversion between gRPC protobuf messages and reckon-gater records.
%%
%% This module isolates all serialization logic. Swapping the gateway
%% protocol (e.g., from gRPC to REST) only requires replacing this module.
-module(reckon_gateway_convert).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-export([
    %% Proto → Gater
    proposed_to_event/2,
    store_id/1,
    subscription_type/1,

    %% Gater → Proto
    event_to_recorded/1,
    snapshot_to_proto/1,
    subscription_to_proto/1,

    %% Helpers
    default_content_type/1
]).

%%====================================================================
%% Proto → Gater
%%====================================================================

%% @doc Convert a ProposedEvent proto map to a new_event map.
%% reckon_db_streams:create_event_record/5 expects maps, not #event{} records.
-spec proposed_to_event(map(), binary()) -> map().
proposed_to_event(Proposed, _StreamId) ->
    EventId = case maps:get(event_id, Proposed, <<>>) of
        <<>> -> generate_uuid();
        Id -> Id
    end,
    DataContentType = default_content_type(
        maps:get(data_content_type, Proposed, <<>>)),
    MetadataContentType = default_content_type(
        maps:get(metadata_content_type, Proposed, <<>>)),
    Data = decode_data(maps:get(data, Proposed, <<>>), DataContentType),
    Metadata = decode_data(maps:get(metadata, Proposed, <<>>), MetadataContentType),
    Tags = case maps:get(tags, Proposed, []) of
        [] -> undefined;
        T -> T
    end,
    #{
        event_id => EventId,
        event_type => maps:get(event_type, Proposed, <<>>),
        data => Data,
        metadata => Metadata,
        tags => Tags,
        data_content_type => DataContentType,
        metadata_content_type => MetadataContentType
    }.

%% @doc Convert a string store_id to an atom.
-spec store_id(binary()) -> atom().
store_id(BinId) ->
    binary_to_existing_atom(BinId, utf8).

%% @doc Convert proto SubscriptionType enum to gater atom.
-spec subscription_type(integer()) -> subscription_type().
subscription_type(0) -> stream;
subscription_type(1) -> stream;
subscription_type(2) -> event_type;
subscription_type(3) -> event_pattern;
subscription_type(4) -> event_payload;
subscription_type(5) -> tags.

%%====================================================================
%% Gater → Proto
%%====================================================================

%% @doc Convert a gater #event{} record to a RecordedEvent proto map.
-spec event_to_recorded(#event{}) -> map().
event_to_recorded(#event{} = E) ->
    #{
        event_id => E#event.event_id,
        event_type => E#event.event_type,
        stream_id => E#event.stream_id,
        version => E#event.version,
        data => encode_data(E#event.data, E#event.data_content_type),
        metadata => encode_data(E#event.metadata, E#event.metadata_content_type),
        tags => case E#event.tags of undefined -> []; T -> T end,
        timestamp => E#event.timestamp,
        epoch_us => E#event.epoch_us,
        data_content_type => E#event.data_content_type,
        metadata_content_type => E#event.metadata_content_type
    }.

%% @doc Convert a gater #snapshot{} record to a SnapshotRecord proto map.
-spec snapshot_to_proto(#snapshot{}) -> map().
snapshot_to_proto(#snapshot{} = S) ->
    #{
        stream_id => S#snapshot.stream_id,
        version => S#snapshot.version,
        data => encode_data(S#snapshot.data, ?CONTENT_TYPE_JSON),
        metadata => encode_data(S#snapshot.metadata, ?CONTENT_TYPE_JSON),
        timestamp => S#snapshot.timestamp
    }.

%% @doc Convert a gater #subscription{} record to a SubscriptionInfo proto map.
-spec subscription_to_proto(#subscription{}) -> map().
subscription_to_proto(#subscription{} = Sub) ->
    #{
        id => Sub#subscription.id,
        type => subscription_type_to_proto(Sub#subscription.type),
        selector => format_selector(Sub#subscription.selector),
        subscription_name => Sub#subscription.subscription_name,
        created_at => Sub#subscription.created_at,
        pool_size => Sub#subscription.pool_size,
        checkpoint => case Sub#subscription.checkpoint of
            undefined -> 0;
            CP -> CP
        end
    }.

%%====================================================================
%% Internal
%%====================================================================

generate_uuid() ->
    reckon_gater_uuid:to_string(reckon_gater_uuid:v7()).

default_content_type(<<>>) -> ?CONTENT_TYPE_JSON;
default_content_type(CT) -> CT.

decode_data(<<>>, _ContentType) ->
    #{};
decode_data(Bytes, ?CONTENT_TYPE_JSON) ->
    json:decode(Bytes);
decode_data(Bytes, _) ->
    Bytes.

encode_data(Data, ?CONTENT_TYPE_JSON) when is_map(Data) ->
    json:encode(Data);
encode_data(Data, _) when is_binary(Data) ->
    Data;
encode_data(Data, _) when is_map(Data) ->
    json:encode(Data);
encode_data(_, _) ->
    <<>>.

subscription_type_to_proto(stream) -> 'SUBSCRIPTION_TYPE_STREAM';
subscription_type_to_proto(by_stream) -> 'SUBSCRIPTION_TYPE_STREAM';
subscription_type_to_proto(event_type) -> 'SUBSCRIPTION_TYPE_EVENT_TYPE';
subscription_type_to_proto(by_event_type) -> 'SUBSCRIPTION_TYPE_EVENT_TYPE';
subscription_type_to_proto(event_pattern) -> 'SUBSCRIPTION_TYPE_EVENT_PATTERN';
subscription_type_to_proto(by_event_pattern) -> 'SUBSCRIPTION_TYPE_EVENT_PATTERN';
subscription_type_to_proto(event_payload) -> 'SUBSCRIPTION_TYPE_EVENT_PAYLOAD';
subscription_type_to_proto(by_event_payload) -> 'SUBSCRIPTION_TYPE_EVENT_PAYLOAD';
subscription_type_to_proto(tags) -> 'SUBSCRIPTION_TYPE_TAGS';
subscription_type_to_proto(by_tags) -> 'SUBSCRIPTION_TYPE_TAGS';
subscription_type_to_proto(_) -> 'SUBSCRIPTION_TYPE_UNSPECIFIED'.

format_selector(Selector) when is_binary(Selector) -> Selector;
format_selector(Selector) when is_map(Selector) -> json:encode(Selector);
format_selector(_) -> <<>>.
