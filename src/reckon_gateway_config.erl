%%% @doc Catalogue config loader for the reckon-gateway.
%%%
%%% Reads operator-curated `clusters.eterm` (path taken from app env
%%% `clusters_config_path`) and validates each cluster spec. The file
%%% is an Erlang term file containing a single list of maps:
%%%
%%%   [
%%%       #{cluster_id => parksim,
%%%         seed       => 'parksim_entry2exit@192.168.1.10',
%%%         cookie     => <<"tKcK...">>},
%%%       ...
%%%   ].
%%%
%%% Cookies are secrets — DO NOT log them, return them in error
%%% messages, or surface them on the gRPC side. They live in the
%%% gateway BEAM's memory + on disk at the configured path (which
%%% MUST be outside any gitops repo, ideally chmod 0600).
-module(reckon_gateway_config).

-export([load_clusters/0]).

-type cluster_spec() :: #{cluster_id := atom(),
                         seed       := atom(),
                         cookie     := binary()}.
-export_type([cluster_spec/0]).

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

normalise(#{cluster_id := Id, seed := Seed, cookie := Cookie} = Spec)
    when is_atom(Id), is_atom(Seed), is_binary(Cookie), byte_size(Cookie) > 0 ->
    {ok, Spec};
normalise(Other) ->
    {error, {invalid_cluster_spec, redact(Other)}}.

%% @private When a spec is malformed we still want a useful error,
%% but we mustn't surface the cookie value in logs or return tuples.
redact(#{cookie := _} = M) -> M#{cookie => <<"<redacted>">>};
redact(M) when is_map(M)   -> M;
redact(Other)              -> Other.
