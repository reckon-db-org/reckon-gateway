%%% @doc Unit tests for the GetServerInfo RPC handler.
%%%
%%% Confirms the response shape, the integrity algorithm identifier,
%%% the per-store integrity-enabled toggling, and — critically — that
%%% the HMAC key itself is never returned in any field.
%%% @end
-module(reckon_gateway_server_info_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Setup / teardown — per-test integrity-state isolation
%%====================================================================

setup_no_integrity(StoreId) ->
    %% Defensive cleanup — earlier tests may have left state.
    persistent_term:erase({reckon_db, integrity_key, StoreId}),
    persistent_term:erase({reckon_db, integrity_enabled, StoreId}),
    ok.

setup_with_integrity(StoreId, Key) when is_binary(Key) ->
    persistent_term:put({reckon_db, integrity_key, StoreId}, Key),
    persistent_term:put({reckon_db, integrity_enabled, StoreId}, true),
    ok.

cleanup(StoreId) ->
    persistent_term:erase({reckon_db, integrity_key, StoreId}),
    persistent_term:erase({reckon_db, integrity_enabled, StoreId}),
    ok.

unique_store_id() ->
    list_to_atom(
        "gw_server_info_test_" ++
        integer_to_list(erlang:unique_integer([positive]))).

call_get_server_info(StoreId) ->
    Md = #{},
    {ok, Resp, _} = reckon_gateway_health_service:get_server_info(
        #{store_id => atom_to_binary(StoreId, utf8)}, Md),
    Resp.

%%====================================================================
%% Disabled-integrity case
%%====================================================================

disabled_store_reports_integrity_off_test() ->
    StoreId = unique_store_id(),
    ok = setup_no_integrity(StoreId),
    Resp = call_get_server_info(StoreId),
    ?assertEqual(false, maps:get(integrity_enabled, Resp)),
    ?assertEqual(<<>>, maps:get(integrity_algo, Resp)),
    ?assertEqual(0, maps:get(hmac_key_id, Resp)),
    cleanup(StoreId).

%%====================================================================
%% Enabled-integrity case
%%====================================================================

enabled_store_reports_algorithm_identifier_test() ->
    StoreId = unique_store_id(),
    Key = crypto:strong_rand_bytes(32),
    ok = setup_with_integrity(StoreId, Key),
    Resp = call_get_server_info(StoreId),
    ?assertEqual(true, maps:get(integrity_enabled, Resp)),
    ?assertEqual(<<"sha256-deterministic-etf-v1">>,
                 maps:get(integrity_algo, Resp)),
    cleanup(StoreId).

enabled_store_reports_key_id_one_test() ->
    %% reckon-db 2.1.0 always uses key_id = 1. Rotation arrives in
    %% 2.2; until then this test locks down the constant so a future
    %% accidental change to a different ID surfaces immediately.
    StoreId = unique_store_id(),
    Key = crypto:strong_rand_bytes(32),
    ok = setup_with_integrity(StoreId, Key),
    Resp = call_get_server_info(StoreId),
    ?assertEqual(1, maps:get(hmac_key_id, Resp)),
    cleanup(StoreId).

%%====================================================================
%% Key material MUST NEVER appear in the response
%%====================================================================

%% The HMAC key itself is the secret. The response advertises that
%% integrity exists and identifies the algorithm; it must NOT leak
%% the key bytes through any field, named or otherwise. This test
%% serialises the whole response and searches for the key bytes —
%% catches accidental inclusion via any path including future
%% fields added by mistake.
key_bytes_are_not_in_response_test() ->
    StoreId = unique_store_id(),
    %% A distinctive key the substring search can find if it leaks.
    Key = <<"SUPER-SECRET-32-byte-key-MARKER!">>,
    32 = byte_size(Key),
    ok = setup_with_integrity(StoreId, Key),
    Resp = call_get_server_info(StoreId),
    Serialised = term_to_binary(Resp),
    ?assertEqual(nomatch, binary:match(Serialised, Key)),
    cleanup(StoreId).

%%====================================================================
%% Response shape — full field set
%%====================================================================

response_has_all_expected_fields_test() ->
    StoreId = unique_store_id(),
    Key = crypto:strong_rand_bytes(32),
    ok = setup_with_integrity(StoreId, Key),
    Resp = call_get_server_info(StoreId),
    Expected = [
        reckon_db_version,
        reckon_gateway_version,
        integrity_algo,
        integrity_enabled,
        hmac_key_id,
        api_compatibility_version
    ],
    [?assertEqual(true, maps:is_key(K, Resp), K) || K <- Expected],
    cleanup(StoreId).

api_compatibility_version_is_v1_test() ->
    StoreId = unique_store_id(),
    ok = setup_no_integrity(StoreId),
    Resp = call_get_server_info(StoreId),
    ?assertEqual(<<"reckon.gateway.v1">>,
                 maps:get(api_compatibility_version, Resp)),
    cleanup(StoreId).
