%%% @doc Unit tests for the GetServerInfo RPC handler.
%%%
%%% Integrity status is now fetched FROM the store via
%%% reckon_gateway_dispatch (the gateway is off the data path, so it can't
%%% read a remote store's integrity from its own local state). These tests
%%% mock the dispatch and confirm the handler forwards the store-reported
%%% status faithfully, and — critically — that no key material can appear in
%%% the response (the gateway never even receives the key now).
%%% @end
-module(reckon_gateway_server_info_tests).

-include_lib("eunit/include/eunit.hrl").

-define(STORE, <<"gw_server_info_test_store">>).
-define(ENABLED_STATUS,
        #{enabled => true, algo => <<"sha256-deterministic-etf-v1">>, key_id => 1}).
-define(DISABLED_STATUS,
        #{enabled => false, algo => <<>>, key_id => 0}).

%% Run get_server_info with the store reporting the given integrity status.
call_with_status(Status) ->
    meck:new(reckon_gateway_dispatch, [passthrough]),
    meck:expect(reckon_gateway_dispatch, call,
                fun(integrity_status, [_StoreId]) -> {ok, Status} end),
    try
        {ok, Resp, _} = reckon_gateway_health_service:get_server_info(
            #{store_id => ?STORE}, #{}),
        Resp
    after
        meck:unload(reckon_gateway_dispatch)
    end.

%%====================================================================
%% Disabled-integrity case
%%====================================================================

disabled_store_reports_integrity_off_test() ->
    Resp = call_with_status(?DISABLED_STATUS),
    ?assertEqual(false, maps:get(integrity_enabled, Resp)),
    ?assertEqual(<<>>, maps:get(integrity_algo, Resp)),
    ?assertEqual(0, maps:get(hmac_key_id, Resp)).

%%====================================================================
%% Enabled-integrity case
%%====================================================================

enabled_store_reports_algorithm_identifier_test() ->
    Resp = call_with_status(?ENABLED_STATUS),
    ?assertEqual(true, maps:get(integrity_enabled, Resp)),
    ?assertEqual(<<"sha256-deterministic-etf-v1">>, maps:get(integrity_algo, Resp)).

enabled_store_reports_key_id_one_test() ->
    %% key_id is fixed at 1 until rotation lands; lock it down so an
    %% accidental change surfaces immediately.
    Resp = call_with_status(?ENABLED_STATUS),
    ?assertEqual(1, maps:get(hmac_key_id, Resp)).

%%====================================================================
%% Key material MUST NEVER appear in the response
%%====================================================================

%% The dispatched status carries only the advert (enabled/algo/key_id),
%% never key bytes — so the key structurally cannot reach the response.
%% This serialises the whole response and asserts a distinctive key marker
%% is absent even if a status map somehow carried it.
key_bytes_are_not_in_response_test() ->
    Key = <<"SUPER-SECRET-32-byte-key-MARKER!">>,
    32 = byte_size(Key),
    %% Even a (buggy) status carrying the key must not leak it through the
    %% advertised fields.
    Base = ?ENABLED_STATUS,
    Status = Base#{key => Key},
    Resp = call_with_status(Status),
    Serialised = term_to_binary(Resp),
    ?assertEqual(nomatch, binary:match(Serialised, Key)).

%%====================================================================
%% Response shape — full field set
%%====================================================================

response_has_all_expected_fields_test() ->
    Resp = call_with_status(?ENABLED_STATUS),
    Expected = [
        reckon_db_version,
        reckon_gateway_version,
        integrity_algo,
        integrity_enabled,
        hmac_key_id,
        api_compatibility_version
    ],
    [?assertEqual(true, maps:is_key(K, Resp), K) || K <- Expected].

api_compatibility_version_is_v1_test() ->
    Resp = call_with_status(?DISABLED_STATUS),
    ?assertEqual(<<"reckon.gateway.v1">>,
                 maps:get(api_compatibility_version, Resp)).
