%%% @doc Unit tests for the embedded-store env contract.
%%%
%%% Drives `reckon_gateway_config:embedded_store_spec/0' across the
%%% modes operators actually configure. Catalogue mode (the default)
%%% MUST stay disabled when no env is set, or we'd silently boot a
%%% store on every 0.5-era deployment that's never seen the new vars.
-module(reckon_gateway_hybrid_mode_tests).

-include_lib("eunit/include/eunit.hrl").

%% Test fixture: every test resets app env + relevant OS env so
%% siblings don't leak state.
setup() ->
    OldAppEnv = [
        {store_enabled,    application:get_env(reckon_gateway, store_enabled)},
        {store_id,         application:get_env(reckon_gateway, store_id)},
        {data_dir,         application:get_env(reckon_gateway, data_dir)},
        {store_mode,       application:get_env(reckon_gateway, store_mode)},
        {local_cluster_id, application:get_env(reckon_gateway, local_cluster_id)}
    ],
    [application:unset_env(reckon_gateway, K) || {K, _} <- OldAppEnv],
    OldOsEnv = [
        {Var, os:getenv(Var)} ||
        Var <- ["RECKON_GATEWAY_STORE_ENABLED",
                "RECKON_GATEWAY_STORE_ID",
                "RECKON_GATEWAY_DATA_DIR",
                "RECKON_GATEWAY_STORE_MODE",
                "RECKON_GATEWAY_LOCAL_CLUSTER_ID"]
    ],
    [os:unsetenv(Var) || {Var, _} <- OldOsEnv],
    {OldAppEnv, OldOsEnv}.

teardown({OldAppEnv, OldOsEnv}) ->
    [application:unset_env(reckon_gateway, K) || {K, _} <- OldAppEnv],
    [case Saved of
         {ok, V} -> application:set_env(reckon_gateway, K, V);
         _       -> ok
     end || {K, Saved} <- OldAppEnv],
    [case Saved of
         false -> os:unsetenv(Var);
         V     -> os:putenv(Var, V)
     end || {Var, Saved} <- OldOsEnv],
    ok.

hybrid_mode_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
        fun catalogue_default_returns_disabled/1,
        fun explicit_false_returns_disabled/1,
        fun unsubstituted_placeholder_treated_as_disabled/1,
        fun true_string_enables_single_mode/1,
        fun one_string_also_enables/1,
        fun cluster_mode_resolves/1,
        fun missing_store_id_when_enabled_errors/1,
        fun missing_data_dir_when_enabled_errors/1,
        fun invalid_store_mode_errors/1,
        fun local_cluster_id_defaults_to_local/1,
        fun app_env_overrides_os_env/1,
        fun indexes_default_empty/1,
        fun indexes_parsed_from_env/1,
        fun indexes_drop_invalid_items/1
    ]}.

%% Catalogue mode (the default): nothing set, anywhere. MUST return
%% `disabled' so the supervisor leaves StoreChildren empty.
catalogue_default_returns_disabled(_) ->
    fun() ->
        ?assertEqual(disabled, reckon_gateway_config:embedded_store_spec())
    end.

explicit_false_returns_disabled(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled, "false"),
        ?assertEqual(disabled, reckon_gateway_config:embedded_store_spec())
    end.

%% No RECKON_GATEWAY_STORE_INDEXES → empty index list (a store pays
%% nothing unless it declares indexes).
indexes_default_empty(_) ->
    fun() ->
        enable_minimal_store(),
        ?assertMatch(#{indexes := []},
                     reckon_gateway_config:embedded_store_spec())
    end.

%% Comma-separated tags / event_type / meta:<key> parse to the
%% reckon-db store_config index_decl() shapes.
indexes_parsed_from_env(_) ->
    fun() ->
        enable_minimal_store(),
        application:set_env(reckon_gateway, store_indexes,
                            "tags,event_type,meta:causation_id,meta:correlation_id"),
        #{indexes := Indexes} = reckon_gateway_config:embedded_store_spec(),
        ?assertEqual([tags, event_type,
                      {meta, <<"causation_id">>}, {meta, <<"correlation_id">>}],
                     Indexes)
    end.

%% Unrecognised items (and empty meta:) are dropped, valid ones kept.
indexes_drop_invalid_items(_) ->
    fun() ->
        enable_minimal_store(),
        application:set_env(reckon_gateway, store_indexes,
                            "tags, bogus , meta: ,meta:k"),
        #{indexes := Indexes} = reckon_gateway_config:embedded_store_spec(),
        ?assertEqual([tags, {meta, <<"k">>}], Indexes)
    end.

%% @private minimal enabled-store env so embedded_store_spec/0 returns a map.
enable_minimal_store() ->
    application:set_env(reckon_gateway, store_enabled, "true"),
    application:set_env(reckon_gateway, store_id, "idx_store"),
    application:set_env(reckon_gateway, data_dir, "/tmp/idx_data").

%% Mirrors what rebar3 sys.config.src looks like before substitution
%% (and what a release built without the env vars set will see at
%% runtime). MUST be treated as "no value supplied" so the gateway
%% falls back to OS env or the default-disabled path.
unsubstituted_placeholder_treated_as_disabled(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled,
                            "${RECKON_GATEWAY_STORE_ENABLED}"),
        ?assertEqual(disabled, reckon_gateway_config:embedded_store_spec())
    end.

true_string_enables_single_mode(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled, "true"),
        application:set_env(reckon_gateway, store_id, "test_store"),
        application:set_env(reckon_gateway, data_dir, "/tmp/test_data"),
        application:set_env(reckon_gateway, store_mode, "single"),
        application:set_env(reckon_gateway, local_cluster_id, "test"),
        Spec = reckon_gateway_config:embedded_store_spec(),
        ?assertMatch(#{store_id   := test_store,
                       data_dir   := "/tmp/test_data",
                       mode       := single,
                       cluster_id := test}, Spec)
    end.

one_string_also_enables(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled, "1"),
        application:set_env(reckon_gateway, store_id, "s"),
        application:set_env(reckon_gateway, data_dir, "/d"),
        ?assertMatch(#{store_id := s, data_dir := "/d", mode := single},
                     reckon_gateway_config:embedded_store_spec())
    end.

cluster_mode_resolves(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled, "true"),
        application:set_env(reckon_gateway, store_id, "node1"),
        application:set_env(reckon_gateway, data_dir, "/data"),
        application:set_env(reckon_gateway, store_mode, "cluster"),
        application:set_env(reckon_gateway, local_cluster_id, "parksim_be"),
        ?assertMatch(#{store_id := node1,
                       data_dir := "/data",
                       mode := cluster,
                       cluster_id := parksim_be},
                     reckon_gateway_config:embedded_store_spec())
    end.

%% When enabled the config MUST refuse to start without identity. A
%% silent fallback would let the operator boot a "store" with no
%% persistent identity, a class of bug the old `_ = dispatch(...)'
%% lesson (Demon 49) is also about: don't swallow misconfigurations.
missing_store_id_when_enabled_errors(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled, "true"),
        application:set_env(reckon_gateway, data_dir, "/d"),
        ?assertError({embedded_store_misconfigured, missing_store_id},
                     reckon_gateway_config:embedded_store_spec())
    end.

missing_data_dir_when_enabled_errors(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled, "true"),
        application:set_env(reckon_gateway, store_id, "s"),
        ?assertError({embedded_store_misconfigured, missing_data_dir},
                     reckon_gateway_config:embedded_store_spec())
    end.

invalid_store_mode_errors(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled, "true"),
        application:set_env(reckon_gateway, store_id, "s"),
        application:set_env(reckon_gateway, data_dir, "/d"),
        application:set_env(reckon_gateway, store_mode, "swarm"),
        ?assertError({embedded_store_misconfigured, {invalid_store_mode, "swarm"}},
                     reckon_gateway_config:embedded_store_spec())
    end.

local_cluster_id_defaults_to_local(_) ->
    fun() ->
        application:set_env(reckon_gateway, store_enabled, "true"),
        application:set_env(reckon_gateway, store_id, "s"),
        application:set_env(reckon_gateway, data_dir, "/d"),
        #{cluster_id := Id} = reckon_gateway_config:embedded_store_spec(),
        ?assertEqual(local, Id)
    end.

%% Verifies the precedence ordering documented in env_string/3: app
%% env (set by sys.config.src substitution) wins over OS env.
app_env_overrides_os_env(_) ->
    fun() ->
        os:putenv("RECKON_GATEWAY_STORE_ENABLED", "false"),
        application:set_env(reckon_gateway, store_enabled, "true"),
        application:set_env(reckon_gateway, store_id, "s"),
        application:set_env(reckon_gateway, data_dir, "/d"),
        ?assertMatch(#{store_id := s},
                     reckon_gateway_config:embedded_store_spec())
    end.
