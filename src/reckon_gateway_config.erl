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

-type embedded_store_spec() :: disabled |
                               #{store_id   := atom(),
                                 data_dir   := string(),
                                 mode       := single | cluster,
                                 cluster_id := atom(),
                                 indexes    := [tags | event_type |
                                                {meta, binary()}]}.

-export_type([cluster_spec/0, embedded_store_spec/0]).

-spec load_clusters() -> {ok, [cluster_spec()]} | {error, term()}.
load_clusters() ->
    case application:get_env(reckon_gateway, clusters_config_path) of
        undefined        -> {ok, []};
        {ok, ""}         -> {ok, []};
        {ok, "${" ++ _}  -> {ok, []};   %% un-substituted placeholder
        {ok, Path}       -> load_from(Path)
    end.

load_from(Path) ->
    case filelib:is_regular(Path) of
        false ->
            %% Allowed: gateway boots with empty catalogue and every
            %% data RPC will return store_unknown.
            logger:warning("[reckon_gateway_config] clusters file not found at ~ts", [Path]),
            {ok, []};
        true ->
            case file:consult(Path) of
                {ok, [Specs]} when is_list(Specs) ->
                    validate(Specs);
                {ok, Other} ->
                    {error, {invalid_format, Path, Other}};
                {error, Reason} ->
                    {error, {read_failed, Path, Reason}}
            end
    end.

validate(Specs) ->
    case validate_loop(Specs, sets:new(), []) of
        {ok, Reversed}  -> {ok, lists:reverse(Reversed)};
        {error, _} = E  -> E
    end.

validate_loop([], _Seen, Acc) ->
    {ok, Acc};
validate_loop([Spec | Rest], Seen, Acc) ->
    case normalise(Spec) of
        {ok, #{cluster_id := Id} = N} ->
            case sets:is_element(Id, Seen) of
                true  -> {error, {duplicate_cluster_id, Id}};
                false -> validate_loop(Rest, sets:add_element(Id, Seen), [N | Acc])
            end;
        {error, _} = E ->
            E
    end.

normalise(#{cluster_id := Id, members := Members, cookie := Cookie} = Spec)
    when is_atom(Id), is_list(Members), is_binary(Cookie),
         byte_size(Cookie) > 0, Members =/= [] ->
    case lists:all(fun erlang:is_atom/1, Members) of
        false -> {error, {invalid_cluster_spec, redact(Spec)}};
        true ->
            case maps:get(api_module, Spec, reckon_gater_api) of
                Mod when is_atom(Mod) ->
                    {ok, Spec#{api_module => Mod}};
                _ ->
                    {error, {invalid_cluster_spec, redact(Spec)}}
            end
    end;
normalise(Other) ->
    {error, {invalid_cluster_spec, redact(Other)}}.

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
        true ->
            #{store_id   => store_id(),
              data_dir   => data_dir(),
              mode       => store_mode(),
              cluster_id => local_cluster_id(),
              indexes    => store_indexes()}
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
    case application:get_env(reckon_gateway, AppKey) of
        {ok, V} ->
            case to_string(V) of
                ""        -> from_os(OsKey, Default);
                "${" ++ _ -> from_os(OsKey, Default);
                S         -> S
            end;
        _ ->
            from_os(OsKey, Default)
    end.

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
