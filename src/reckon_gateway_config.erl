%%% @doc Catalogue config loader for the reckon-gateway.
%%%
%%% Reads operator-curated clusters.eterm (path from app env
%%% clusters_config_path) and validates each cluster spec. The file
%%% is an Erlang term file containing a single list of maps:
%%%
%%%   [
%%%       #{cluster_id => parksim,
%%%         members    => ['parksim_entry2exit@192.168.1.10',
%%%                        'parksim_lot@192.168.1.11',
%%%                        'parksim_pricing@192.168.1.12',
%%%                        'parksim_simulator@192.168.1.13'],
%%%         cookie     => the binary "tKcK..."},
%%%       ...
%%%   ].
%%%
%%% The members key is an explicit list of every node in the cluster.
%%% The connector connects to each directly; no reliance on the
%%% cluster having a healthy internal mesh.
%%%
%%% Cookies are secrets; DO NOT log them, return them in error
%%% messages, or surface them on the gRPC side. They live in the
%%% gateway BEAM's memory + on disk at the configured path (which
%%% MUST be outside any gitops repo, ideally chmod 0600).
-module(reckon_gateway_config).

-export([load_clusters/0, embedded_store_spec/0]).

-type cluster_spec() :: #{cluster_id := atom(),
                         members    := [node()],
                         cookie     := binary(),
                         api_module => atom()}.   %% defaults to reckon_gater_api

-type index_decl() :: tags | event_type |
                      {meta, binary()} |
                      {payload, binary()} |
                      {payload_hash, [binary()]}.

-type integrity_cfg() :: disabled |
                         #{enabled := true,
                           key_source := {env_var, binary()} |
                                         {sealed_file, string()}}.

%% The embedded-store spec mirrors reckon-db's #store_config{}. The
%% required fields (store_id/data_dir/mode/cluster_id/indexes) always
%% resolve (env or store.eterm). The optional tuning fields are
%% `undefined' unless the operator set them in store.eterm, in which
%% case the store_starter overrides reckon-db's record defaults.
-type embedded_store_spec() :: disabled |
                               #{store_id          := atom(),
                                 data_dir          := string(),
                                 mode              := single | cluster,
                                 cluster_id        := atom(),
                                 indexes           := [index_decl()],
                                 timeout           := pos_integer() | undefined,
                                 writer_pool_size  := pos_integer() | undefined,
                                 reader_pool_size  := pos_integer() | undefined,
                                 gateway_pool_size := pos_integer() | undefined,
                                 options           := map() | undefined,
                                 integrity         := integrity_cfg() | undefined}.

-export_type([cluster_spec/0, embedded_store_spec/0, index_decl/0]).

-spec load_clusters() -> {ok, [cluster_spec()]} | {error, term()}.
load_clusters() ->
    case application:get_env(reckon_gateway, clusters_config_path) of
        undefined        -> {ok, []};
        {ok, ""}         -> {ok, []};
        {ok, "${" ++ _}  -> {ok, []};   %% un-substituted placeholder
        {ok, Path}       -> load_from(Path)
    end.

load_from(Path) ->
    load_existing(filelib:is_regular(Path), Path).

load_existing(false, Path) ->
    %% Allowed: gateway boots with empty catalogue and every data RPC
    %% will return store_unknown.
    logger:warning("[reckon_gateway_config] clusters file not found at ~ts", [Path]),
    {ok, []};
load_existing(true, Path) ->
    consult_specs(file:consult(Path), Path).

consult_specs({ok, [Specs]}, _Path) when is_list(Specs) ->
    validate(Specs);
consult_specs({ok, Other}, Path) ->
    {error, {invalid_format, Path, Other}};
consult_specs({error, Reason}, Path) ->
    {error, {read_failed, Path, Reason}}.

validate(Specs) ->
    case validate_loop(Specs, sets:new(), []) of
        {ok, Reversed}  -> {ok, lists:reverse(Reversed)};
        {error, _} = E  -> E
    end.

validate_loop([], _Seen, Acc) ->
    {ok, Acc};
validate_loop([Spec | Rest], Seen, Acc) ->
    validate_normalised(normalise(Spec), Rest, Seen, Acc).

validate_normalised({ok, #{cluster_id := Id} = N}, Rest, Seen, Acc) ->
    validate_dedup(sets:is_element(Id, Seen), Id, N, Rest, Seen, Acc);
validate_normalised({error, _} = E, _Rest, _Seen, _Acc) ->
    E.

validate_dedup(true, Id, _N, _Rest, _Seen, _Acc) ->
    {error, {duplicate_cluster_id, Id}};
validate_dedup(false, Id, N, Rest, Seen, Acc) ->
    validate_loop(Rest, sets:add_element(Id, Seen), [N | Acc]).

normalise(#{cluster_id := Id, members := Members, cookie := Cookie} = Spec)
    when is_atom(Id), is_list(Members), is_binary(Cookie),
         byte_size(Cookie) > 0, Members =/= [] ->
    normalise_members(lists:all(fun erlang:is_atom/1, Members), Spec);
normalise(Other) ->
    {error, {invalid_cluster_spec, redact(Other)}}.

normalise_members(false, Spec) ->
    {error, {invalid_cluster_spec, redact(Spec)}};
normalise_members(true, Spec) ->
    normalise_api_module(maps:get(api_module, Spec, reckon_gater_api), Spec).

normalise_api_module(Mod, Spec) when is_atom(Mod) ->
    {ok, Spec#{api_module => Mod}};
normalise_api_module(_, Spec) ->
    {error, {invalid_cluster_spec, redact(Spec)}}.

%% @private When a spec is malformed we still want a useful error,
%% but we mustn't surface the cookie value in logs or return tuples.
redact(#{cookie := _} = M) -> M#{cookie => <<"<redacted>">>};
redact(M) when is_map(M)   -> M;
redact(Other)              -> Other.

%%====================================================================
%% Embedded store config — env-driven, optional
%%====================================================================

%% @doc Return the embedded-store spec or `disabled' based on app env.
%%
%% Reads (in order): app env → OS env → default. The release's
%% `sys.config.src' substitutes `${RECKON_GATEWAY_STORE_*}' into app
%% env at boot, so OS env wins by the time we get here.
-spec embedded_store_spec() -> embedded_store_spec().
embedded_store_spec() ->
    case enabled() of
        false -> disabled;
        true  -> build_spec(load_store_file())
    end.

%% @private Resolve every store_config field. The optional store.eterm
%% map wins per-field; env (then default) fills anything it omits. This
%% keeps env-only deployments working unchanged while letting the file
%% declare the advanced surface (payload indexes, integrity, pools).
build_spec(FileMap) ->
    #{store_id          => field(FileMap, store_id,   fun store_id/0),
      data_dir          => field(FileMap, data_dir,   fun data_dir/0),
      mode              => field(FileMap, mode,        fun store_mode/0),
      cluster_id        => field(FileMap, cluster_id,  fun local_cluster_id/0),
      indexes           => field(FileMap, indexes,     fun store_indexes/0),
      timeout           => maps:get(timeout,           FileMap, undefined),
      writer_pool_size  => maps:get(writer_pool_size,  FileMap, undefined),
      reader_pool_size  => maps:get(reader_pool_size,  FileMap, undefined),
      gateway_pool_size => maps:get(gateway_pool_size, FileMap, undefined),
      options           => maps:get(options,           FileMap, undefined),
      integrity         => maps:get(integrity,         FileMap, undefined)}.

field(FileMap, Key, EnvFun) ->
    case maps:find(Key, FileMap) of
        {ok, V} -> V;
        error   -> EnvFun()
    end.

%%====================================================================
%% store.eterm — optional full #store_config{} declaration
%%====================================================================

%% @private Load + validate the operator's store.eterm. Absent file is
%% fine (env-only mode → empty map). A present-but-invalid file is a
%% hard boot failure, same posture as the env misconfig crashes below.
load_store_file() ->
    load_store_path(store_config_path()).

load_store_path(none) -> #{};
load_store_path(Path) -> load_store_regular(filelib:is_regular(Path), Path).

load_store_regular(false, _Path) -> #{};
load_store_regular(true, Path)   -> consult_store(file:consult(Path), Path).

consult_store({ok, [Map]}, Path) when is_map(Map) ->
    validate_store_map(Map, Path);
consult_store({ok, Other}, Path) ->
    erlang:error({embedded_store_misconfigured,
                  {invalid_store_config_file, Path, {expected_single_map, Other}}});
consult_store({error, Reason}, Path) ->
    erlang:error({embedded_store_misconfigured,
                  {invalid_store_config_file, Path, {read_failed, Reason}}}).

validate_store_map(Map, Path) ->
    case validate_store_keys(maps:to_list(Map)) of
        ok              -> Map;
        {error, Reason} -> erlang:error({embedded_store_misconfigured,
                                         {invalid_store_config_file, Path, Reason}})
    end.

validate_store_keys([]) -> ok;
validate_store_keys([{K, V} | Rest]) ->
    case valid_store_field(K, V) of
        true  -> validate_store_keys(Rest);
        false -> {error, {invalid_field, K, V}}
    end.

valid_store_field(store_id, V)          -> is_atom(V);
valid_store_field(data_dir, V)          -> is_list(V);
valid_store_field(cluster_id, V)        -> is_atom(V);
valid_store_field(mode, V)              -> V =:= single orelse V =:= cluster;
valid_store_field(timeout, V)           -> is_integer(V) andalso V > 0;
valid_store_field(writer_pool_size, V)  -> is_integer(V) andalso V > 0;
valid_store_field(reader_pool_size, V)  -> is_integer(V) andalso V > 0;
valid_store_field(gateway_pool_size, V) -> is_integer(V) andalso V > 0;
valid_store_field(options, V)           -> is_map(V);
valid_store_field(indexes, V)           -> is_list(V) andalso lists:all(fun valid_index/1, V);
valid_store_field(integrity, V)         -> valid_integrity(V);
valid_store_field(_, _)                 -> false.

valid_index(tags)                            -> true;
valid_index(event_type)                      -> true;
valid_index({meta, K})                       -> is_binary(K);
valid_index({payload, K})                    -> is_binary(K);
valid_index({payload_hash, Ks}) when is_list(Ks) -> lists:all(fun erlang:is_binary/1, Ks);
valid_index(_)                               -> false.

valid_integrity(disabled) -> true;
valid_integrity(#{enabled := true, key_source := Src}) -> valid_key_source(Src);
valid_integrity(_) -> false.

valid_key_source({env_var, Name})    -> is_binary(Name);
valid_key_source({sealed_file, Path}) -> is_list(Path);
valid_key_source(_)                   -> false.

store_config_path() ->
    case env_string(store_config_path, "RECKON_GATEWAY_STORE_PATH",
                    "/etc/reckon-gateway/store.eterm") of
        ""   -> none;
        Path -> Path
    end.

%% @private Declared secondary indexes for the embedded store (reckon-db
%% 5.0.0+). Comma-separated list in RECKON_GATEWAY_STORE_INDEXES; each item
%% is `tags', `event_type', or `meta:<key>'. Empty/unset → no indexes. e.g.
%% `tags,event_type,meta:causation_id,meta:correlation_id'.
store_indexes() ->
    parse_indexes(env_string(store_indexes, "RECKON_GATEWAY_STORE_INDEXES", "")).

parse_indexes(Str) ->
    lists:append([decl_of(string:trim(Raw)) || Raw <- string:lexemes(Str, ",")]).

%% Returns a one-element list with the decl, or [] to drop an invalid item.
decl_of("") -> [];
decl_of("tags") -> [tags];
decl_of("event_type") -> [event_type];
decl_of("meta:" ++ Key) when Key =/= "" -> [{meta, list_to_binary(Key)}];
decl_of(Other) ->
    logger:warning("[reckon_gateway_config] ignoring invalid index "
                   "declaration ~ts in RECKON_GATEWAY_STORE_INDEXES", [Other]),
    [].

%% @private Tolerantly detect the on/off flag.
enabled() ->
    case env_string(store_enabled, "RECKON_GATEWAY_STORE_ENABLED", "false") of
        "true" -> true;
        "1"    -> true;
        "yes"  -> true;
        _      -> false
    end.

store_id() ->
    case env_string(store_id, "RECKON_GATEWAY_STORE_ID", "") of
        ""   -> erlang:error({embedded_store_misconfigured, missing_store_id});
        Name -> list_to_atom(Name)
    end.

data_dir() ->
    case env_string(data_dir, "RECKON_GATEWAY_DATA_DIR", "") of
        ""   -> erlang:error({embedded_store_misconfigured, missing_data_dir});
        Path -> Path
    end.

store_mode() ->
    case env_string(store_mode, "RECKON_GATEWAY_STORE_MODE", "single") of
        "single"  -> single;
        "cluster" -> cluster;
        Other ->
            erlang:error({embedded_store_misconfigured,
                          {invalid_store_mode, Other}})
    end.

local_cluster_id() ->
    list_to_atom(env_string(local_cluster_id,
                            "RECKON_GATEWAY_LOCAL_CLUSTER_ID", "local")).

%% Read app env → OS env → default. App env wins because the release's
%% sys.config.src interpolates OS env into it; this pattern lets the
%% test harness override via application:set_env/3 without touching
%% the OS environment. Un-substituted `${VAR}' placeholders fall through
%% to the OS env path.
env_string(AppKey, OsKey, Default) ->
    env_string_app(application:get_env(reckon_gateway, AppKey), OsKey, Default).

env_string_app({ok, V}, OsKey, Default) ->
    env_string_value(to_string(V), OsKey, Default);
env_string_app(_, OsKey, Default) ->
    from_os(OsKey, Default).

env_string_value("", OsKey, Default)        -> from_os(OsKey, Default);
env_string_value("${" ++ _, OsKey, Default) -> from_os(OsKey, Default);
env_string_value(S, _OsKey, _Default)       -> S.

to_string(V) when is_list(V)   -> V;
to_string(V) when is_atom(V)   -> atom_to_list(V);
to_string(V) when is_binary(V) -> binary_to_list(V);
to_string(_)                   -> "".

from_os(OsKey, Default) ->
    case os:getenv(OsKey) of
        false     -> Default;
        ""        -> Default;
        "${" ++ _ -> Default;
        V         -> V
    end.
