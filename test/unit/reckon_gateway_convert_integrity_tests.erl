%%% @doc Unit tests for the gateway egress integrity boundary.
%%%
%%% Locks down the two non-negotiable properties of
%%% reckon_gateway_convert in the 0.2.0+ era:
%%%
%%%   1. prev_event_hash IS propagated to the proto map. Polyglot
%%%      clients receive it and can verify chain continuity locally.
%%%
%%%   2. The mac field is NEVER propagated. It is a symmetric secret
%%%      bound to the per-store HMAC key; leaking it across the wire
%%%      defeats its purpose.
%%%
%%% These tests exist primarily as guardrails — they MUST fail loudly
%%% if a future change to event_to_recorded/1 starts copying the mac
%%% field. A regression here would be a silent security incident.
%%% @end
-module(reckon_gateway_convert_integrity_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

%%====================================================================
%% RecordedEvent — prev_event_hash propagation
%%====================================================================

intact_event_propagates_prev_event_hash_test() ->
    Hash = sample_hash(),
    Event = base_event(Hash, sample_mac()),
    Proto = reckon_gateway_convert:event_to_recorded(Event),
    ?assertEqual(Hash, maps:get(prev_event_hash, Proto)).

legacy_event_emits_empty_prev_event_hash_test() ->
    %% A legacy event (pre-2.1 reckon-db) has prev_event_hash =
    %% undefined. The gateway must translate that to an empty binary
    %% on the wire, never `undefined` (which the proto layer would
    %% mishandle).
    Event = base_event(undefined, undefined),
    Proto = reckon_gateway_convert:event_to_recorded(Event),
    ?assertEqual(<<>>, maps:get(prev_event_hash, Proto)).

%%====================================================================
%% RecordedEvent — MAC NEVER leaves the server
%%====================================================================

%% This is the load-bearing test of the gateway egress boundary.
%% If any future change to event_to_recorded/1 starts putting the
%% mac field into the proto map, this test must fail at compile
%% time (mac would not be a known proto field) or at runtime (the
%% mac key would appear in the resulting map). Both are caught here.
mac_field_is_not_in_proto_map_test() ->
    Event = base_event(sample_hash(), sample_mac()),
    Proto = reckon_gateway_convert:event_to_recorded(Event),
    %% The mac field must not appear in the proto map under ANY key.
    %% This catches:
    %%   - direct copies (proto[mac] = E#event.mac)
    %%   - accidental serialisation via maps:merge with the full
    %%     record fields as a map
    %%   - any future field rename that collides
    ?assertNot(maps:is_key(mac, Proto)),
    ?assertNot(maps:is_key(<<"mac">>, Proto)),
    %% Also ensure the MAC bytes themselves do not appear anywhere
    %% in the serialised proto (defensive check against accidental
    %% inclusion via a different field name).
    {1, MacBytes} = Event#event.mac,
    ?assertNot(map_contains_value(Proto, MacBytes)).

signature_field_is_not_in_proto_map_test() ->
    %% signature is reserved for Ed25519 in a future release; until
    %% then, even if a record happens to carry one (via direct
    %% storage tampering or testing), it must not leak via the
    %% gateway proto.
    Event = (base_event(sample_hash(), sample_mac()))#event{
        signature = <<"future-ed25519-sig">>
    },
    Proto = reckon_gateway_convert:event_to_recorded(Event),
    ?assertNot(maps:is_key(signature, Proto)),
    ?assertNot(maps:is_key(<<"signature">>, Proto)),
    ?assertNot(map_contains_value(Proto, <<"future-ed25519-sig">>)).

%%====================================================================
%% SnapshotRecord — anchor_hash propagation; mac never leaves
%%====================================================================

intact_snapshot_propagates_anchor_hash_test() ->
    Anchor = sample_hash(),
    Snap = base_snapshot(Anchor, sample_mac()),
    Proto = reckon_gateway_convert:snapshot_to_proto(Snap),
    ?assertEqual(Anchor, maps:get(anchor_hash, Proto)).

legacy_snapshot_emits_empty_anchor_hash_test() ->
    Snap = base_snapshot(undefined, undefined),
    Proto = reckon_gateway_convert:snapshot_to_proto(Snap),
    ?assertEqual(<<>>, maps:get(anchor_hash, Proto)).

snapshot_mac_field_is_not_in_proto_map_test() ->
    Snap = base_snapshot(sample_hash(), sample_mac()),
    Proto = reckon_gateway_convert:snapshot_to_proto(Snap),
    ?assertNot(maps:is_key(mac, Proto)),
    {1, MacBytes} = Snap#snapshot.mac,
    ?assertNot(map_contains_value(Proto, MacBytes)).

%%====================================================================
%% Schema sanity — proto map shape covers all expected fields
%%====================================================================

recorded_event_proto_has_expected_fields_test() ->
    Event = base_event(sample_hash(), sample_mac()),
    Proto = reckon_gateway_convert:event_to_recorded(Event),
    %% The wire-format fields that SHOULD be present (whitelist).
    Expected = [
        event_id, event_type, stream_id, version,
        data, metadata, tags, timestamp, epoch_us,
        data_content_type, metadata_content_type,
        prev_event_hash
    ],
    [?assertEqual(true, maps:is_key(K, Proto), K) || K <- Expected].

snapshot_proto_has_expected_fields_test() ->
    Snap = base_snapshot(sample_hash(), sample_mac()),
    Proto = reckon_gateway_convert:snapshot_to_proto(Snap),
    Expected = [stream_id, version, data, metadata, timestamp, anchor_hash],
    [?assertEqual(true, maps:is_key(K, Proto), K) || K <- Expected].

%%====================================================================
%% Helpers
%%====================================================================

base_event(PrevHash, Mac) ->
    #event{
        event_id = <<"019ef-test">>,
        event_type = <<"thing_happened_v1">>,
        stream_id = <<"thing-1">>,
        version = 5,
        data = #{value => 42},
        metadata = #{},
        tags = undefined,
        timestamp = 1747000000000,
        epoch_us = 1747000000000000,
        data_content_type = <<"application/json">>,
        metadata_content_type = <<"application/json">>,
        prev_event_hash = PrevHash,
        mac = Mac,
        signature = undefined
    }.

base_snapshot(AnchorHash, Mac) ->
    #snapshot{
        stream_id = <<"thing-1">>,
        version = 42,
        data = #{state => running},
        metadata = #{},
        timestamp = 1747000000000,
        anchor_hash = AnchorHash,
        mac = Mac
    }.

sample_hash() ->
    %% 32-byte SHA-256-shaped value (the actual bytes do not matter
    %% for these conversion tests; only that they propagate verbatim).
    <<1, 2, 3, 4, 5, 6, 7, 8,
      9, 10, 11, 12, 13, 14, 15, 16,
      17, 18, 19, 20, 21, 22, 23, 24,
      25, 26, 27, 28, 29, 30, 31, 32>>.

sample_mac() ->
    %% A plausible {KeyId, MacBytes} as would appear on the storage
    %% side. The bytes are deliberately distinct from sample_hash()
    %% so the "MAC must not leak" tests can distinguish them.
    {1, <<200, 201, 202, 203, 204, 205, 206, 207,
          208, 209, 210, 211, 212, 213, 214, 215,
          216, 217, 218, 219, 220, 221, 222, 223,
          224, 225, 226, 227, 228, 229, 230, 231>>}.

%% Flat scan: confirm a binary target does not appear inside the
%% serialised representation of the proto map. Uses term_to_binary
%% to flatten EVERYTHING (nested maps, lists, tuples, iolists from
%% encoded data fields) into a single binary, then does a substring
%% search. This catches any path through which MAC bytes might leak
%% — including encoding within a JSON-shaped data field — without
%% needing to recurse through arbitrarily nested iolist structures
%% in the helper itself.
map_contains_value(Map, Target) when is_binary(Target) ->
    Serialised = term_to_binary(Map),
    binary:match(Serialised, Target) =/= nomatch.
