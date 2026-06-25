%%% @doc Boots the optional embedded reckon-db store from env config.
%%%
%%% Started by `reckon_gateway_sup' only when
%%% `RECKON_GATEWAY_STORE_ENABLED=true'. The starter is a transient
%%% worker that calls `reckon_db_sup:start_store/1' in its `init/1'
%%% and returns `ignore' — the actual store process is owned by
%%% reckon-db's own supervision tree (`reckon_db_sup'), not this
%%% module.
%%%
%%% The starter exists only to:
%%%   1. read env (via `reckon_gateway_config:embedded_store_spec/0')
%%%   2. construct the `#store_config{}' record
%%%   3. invoke `reckon_db_sup:start_store/1' exactly once
%%%
%%% After that the store is live, self-announces to
%%% `reckon_db_store_registry' via pg, and the local connector
%%% picks it up on its next refresh tick.
-module(reckon_gateway_store_starter).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, child_spec/0]).

-spec start_link() -> ignore | {error, term()}.
start_link() ->
    start_with_spec(reckon_gateway_config:embedded_store_spec()).

start_with_spec(disabled) ->
    logger:info("[reckon_gateway_store_starter] embedded store disabled"),
    ignore;
start_with_spec(#{store_id := StoreId, data_dir := DataDir, mode := Mode} = Spec) ->
    start_with_dir(ensure_data_dir(DataDir), StoreId, DataDir, Mode, Spec).

start_with_dir({error, Reason} = E, _StoreId, DataDir, _Mode, _Spec) ->
    logger:error("[reckon_gateway_store_starter] data_dir ~ts: ~p", [DataDir, Reason]),
    E;
start_with_dir(ok, StoreId, DataDir, Mode, Spec) ->
    Config = #store_config{
        store_id = StoreId,
        data_dir = DataDir,
        mode     = Mode,
        indexes  = maps:get(indexes, Spec, [])
    },
    logger:info(
        "[reckon_gateway_store_starter] starting store ~p "
        "(mode=~p data_dir=~ts cluster_id=~p)",
        [StoreId, Mode, DataDir, maps:get(cluster_id, Spec)]),
    handle_start(reckon_db_sup:start_store(Config), StoreId).

handle_start({ok, _Pid}, _StoreId) ->
    ignore;
handle_start({error, {already_started, _}}, _StoreId) ->
    ignore;
handle_start({error, Reason} = E, StoreId) ->
    logger:error(
        "[reckon_gateway_store_starter] start_store ~p failed: ~p", [StoreId, Reason]),
    E.

-spec child_spec() -> supervisor:child_spec().
child_spec() ->
    #{id       => ?MODULE,
      start    => {?MODULE, start_link, []},
      restart  => transient,
      shutdown => 5000,
      type     => worker,
      modules  => [?MODULE]}.

%% @private Ensure the data directory exists and is writable. Khepri
%% will create subdirs under it, but the root must exist.
ensure_data_dir(DataDir) ->
    case filelib:ensure_dir(filename:join(DataDir, ".keep")) of
        ok              -> ok;
        {error, _} = E  -> E
    end.
