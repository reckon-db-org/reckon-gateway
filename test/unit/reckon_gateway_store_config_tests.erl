%%% @doc Unit tests for the embedded-store config resolution.
%%%
%%% Locks down the store.eterm contract added when the gateway became
%%% able to host (and fully configure) a reckon-db store:
%%%
%%%   1. No file  -> env-only spec; optional tuning fields are
%%%      `undefined' so reckon-db's #store_config{} defaults stand.
%%%   2. File present -> its fields win per-field over env, including
%%%      the advanced surface env can't express: {payload, _} /
%%%      {payload_hash, _} indexes and integrity.
%%%   3. A malformed file is a HARD boot failure, never a silent
%%%      fallback to a half-configured store.
%%%
%%% Exercised through the public embedded_store_spec/0 — the real
%%% contract the store_starter depends on.
-module(reckon_gateway_store_config_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Fixture
%%====================================================================

%% App-env keys we mutate; snapshot + restore so tests don't leak.
keys() -> [store_enabled, store_id, data_dir, store_mode,
           local_cluster_id, store_indexes, store_config_path].

setup() ->
    Saved = [{K, application:get_env(reckon_gateway, K)} || K <- keys()],
    [application:unset_env(reckon_gateway, K) || K <- keys()],
    application:set_env(reckon_gateway, store_enabled, "true"),
    application:set_env(reckon_gateway, store_id, "env_store"),
    application:set_env(reckon_gateway, data_dir, "/data/env"),
    Saved.

cleanup(Saved) ->
    [application:unset_env(reckon_gateway, K) || K <- keys()],
    [restore(K, V) || {K, V} <- Saved],
    ok.

restore(_K, undefined)  -> ok;
restore(K, {ok, V})     -> application:set_env(reckon_gateway, K, V).

write_store_file(Term) ->
    Dir  = filename:join(["_build", "test", "store_cfg_fixtures"]),
    ok   = filelib:ensure_dir(filename:join(Dir, ".keep")),
    Path = filename:join(Dir, lists:flatten(io_lib:format("store_~p.eterm", [erlang:unique_integer([positive])]))),
    ok   = file:write_file(Path, io_lib:format("~p.~n", [Term])),
    application:set_env(reckon_gateway, store_config_path, Path),
    Path.

with_fixture(Fun) ->
    Saved = setup(),
    try Fun() after cleanup(Saved) end.

%%====================================================================
%% No file: env-only, optional fields undefined
%%====================================================================

env_only_spec_test() ->
    with_fixture(fun() ->
        %% Point at a path that does not exist -> env-only resolution.
        application:set_env(reckon_gateway, store_config_path, "/nonexistent/store.eterm"),
        application:set_env(reckon_gateway, store_indexes, "tags,event_type"),
        Spec = reckon_gateway_config:embedded_store_spec(),
        ?assertEqual(env_store, maps:get(store_id, Spec)),
        ?assertEqual("/data/env", maps:get(data_dir, Spec)),
        ?assertEqual([tags, event_type], maps:get(indexes, Spec)),
        ?assertEqual(undefined, maps:get(timeout, Spec)),
        ?assertEqual(undefined, maps:get(writer_pool_size, Spec)),
        ?assertEqual(undefined, maps:get(integrity, Spec))
    end).

%%====================================================================
%% File present: per-field override incl. payload indexes + integrity
%%====================================================================

file_overrides_and_extends_test() ->
    with_fixture(fun() ->
        write_store_file(#{
            store_id => file_store,
            mode     => cluster,
            timeout  => 9000,
            writer_pool_size => 4,
            indexes  => [tags,
                         {payload, <<"account_id">>},
                         {payload_hash, [<<"flight_id">>, <<"seat_no">>]}],
            integrity => #{enabled => true,
                           key_source => {env_var, <<"RECKON_HMAC">>}}
        }),
        Spec = reckon_gateway_config:embedded_store_spec(),
        %% File wins where set...
        ?assertEqual(file_store, maps:get(store_id, Spec)),
        ?assertEqual(cluster, maps:get(mode, Spec)),
        ?assertEqual(9000, maps:get(timeout, Spec)),
        ?assertEqual(4, maps:get(writer_pool_size, Spec)),
        ?assertEqual([tags,
                      {payload, <<"account_id">>},
                      {payload_hash, [<<"flight_id">>, <<"seat_no">>]}],
                     maps:get(indexes, Spec)),
        ?assertEqual(#{enabled => true, key_source => {env_var, <<"RECKON_HMAC">>}},
                     maps:get(integrity, Spec)),
        %% ...env fills what the file omits.
        ?assertEqual("/data/env", maps:get(data_dir, Spec))
    end).

%%====================================================================
%% Malformed file: hard boot failure
%%====================================================================

invalid_index_crashes_test() ->
    with_fixture(fun() ->
        write_store_file(#{indexes => [{payload, "not_a_binary"}]}),
        ?assertError({embedded_store_misconfigured,
                      {invalid_store_config_file, _, {invalid_field, indexes, _}}},
                     reckon_gateway_config:embedded_store_spec())
    end).

invalid_integrity_crashes_test() ->
    with_fixture(fun() ->
        write_store_file(#{integrity => #{enabled => true, key_source => bogus}}),
        ?assertError({embedded_store_misconfigured,
                      {invalid_store_config_file, _, {invalid_field, integrity, _}}},
                     reckon_gateway_config:embedded_store_spec())
    end).

not_a_map_crashes_test() ->
    with_fixture(fun() ->
        write_store_file([this, is, a, list]),
        ?assertError({embedded_store_misconfigured,
                      {invalid_store_config_file, _, _}},
                     reckon_gateway_config:embedded_store_spec())
    end).
