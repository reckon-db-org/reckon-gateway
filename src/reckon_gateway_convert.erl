%% @doc Conversion between gRPC protobuf messages and reckon-gater records.
%%
%% This module isolates all serialization logic. Swapping the gateway
%% protocol (e.g., from gRPC to REST) only requires replacing this module.
-module(reckon_gateway_convert).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").

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
%%
%% Uses `binary_to_atom/2', NOT `binary_to_existing_atom/2', so
%% clients can create new stores on demand. To prevent atom-table
%% exhaustion attacks, the input is length-capped (64 bytes) and
%% must match a conservative identifier regex.
%%
%% Crashes with `{invalid_store_id, BinId}' on violation, which the
%% gRPC handler surfaces as `INVALID_ARGUMENT' (status 3).
-define(STORE_ID_REGEX, <<"^[a-zA-Z][a-zA-Z0-9_-]*$">>).
-define(STORE_ID_MAX_BYTES, 64).

-spec store_id(binary()) -> atom().
store_id(BinId) when is_binary(BinId), byte_size(BinId) =< ?STORE_ID_MAX_BYTES ->
    case re:run(BinId, ?STORE_ID_REGEX, [{capture, none}]) of
        match   -> binary_to_atom(BinId, utf8);
        nomatch -> error({invalid_store_id, BinId})
    end;
store_id(BinId) ->
    error({invalid_store_id, BinId}).

%% @doc Convert proto SubscriptionType enum to gater atom.
%%
%% gpb decodes proto enums to the atom form on the wire (e.g.
%% `'SUBSCRIPTION_TYPE_STREAM''), not the integer ordinal — so the
%% atom clauses below are the real path the Subscribe handler hits.
%% The integer clauses remain for callers that pre-converted.
-spec subscription_type(integer() | atom()) -> subscription_type().
subscription_type('SUBSCRIPTION_TYPE_UNSPECIFIED')   -> stream;
subscription_type('SUBSCRIPTION_TYPE_STREAM')        -> stream;
subscription_type('SUBSCRIPTION_TYPE_EVENT_TYPE')    -> event_type;
subscription_type('SUBSCRIPTION_TYPE_EVENT_PATTERN') -> event_pattern;
subscription_type('SUBSCRIPTION_TYPE_EVENT_PAYLOAD') -> event_payload;
subscription_type('SUBSCRIPTION_TYPE_TAGS')          -> tags;
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
%%
%% Egress integrity policy (reckon-gateway 0.2.0):
%%   - prev_event_hash IS propagated. Polyglot clients can verify
%%     chain continuity with their own SHA-256 implementation.
%%   - mac is NEVER propagated. The HMAC is a symmetric secret bound
%%     to the per-store key; leaking it to gateway clients would
%%     defeat its purpose. External authenticity is the job of a
%%     future Ed25519 signature field, not the storage-layer MAC.
%%   - signature is reserved for the same future role; not yet
%%     populated server-side, not yet exposed on the wire.
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
        metadata_content_type => E#event.metadata_content_type,
        prev_event_hash => integrity_bytes(E#event.prev_event_hash)
    }.

%% @doc Convert a gater #snapshot{} record to a SnapshotRecord proto map.
%%
%% Egress integrity policy: anchor_hash on the wire; mac NEVER on the
%% wire. Same rationale as event_to_recorded/1.
-spec snapshot_to_proto(#snapshot{}) -> map().
snapshot_to_proto(#snapshot{} = S) ->
    #{
        stream_id => S#snapshot.stream_id,
        version => S#snapshot.version,
        data => encode_data(S#snapshot.data, ?CONTENT_TYPE_JSON),
        metadata => encode_data(S#snapshot.metadata, ?CONTENT_TYPE_JSON),
        timestamp => S#snapshot.timestamp,
        anchor_hash => integrity_bytes(S#snapshot.anchor_hash)
    }.

%% @private Wire-format helper for the optional integrity hash fields.
%%
%% Proto3 `bytes` is non-nullable; `undefined` on the Erlang side maps
%% to an empty binary on the wire. Clients receiving empty bytes
%% should interpret it as "legacy event/snapshot — no integrity"
%% rather than "integrity check failed".
integrity_bytes(undefined) -> <<>>;
integrity_bytes(Hash) when is_binary(Hash) -> Hash.

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
