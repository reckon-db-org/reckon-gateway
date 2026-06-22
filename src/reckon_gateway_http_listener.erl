%%% @doc Cowboy HTTP listener for the JSON/REST API and admin UI.
%%%
%%% Starts a separate Cowboy HTTP listener (HTTP/1.1 + HTTP/2 via upgrade)
%%% on RECKON_GATEWAY_HTTP_PORT (default 8080). The gRPC listener stays on
%%% its own port (RECKON_GATEWAY_PORT, default 50051).
%%%
%%% Routes:
%%%   GET  /v1/health                        gateway health
%%%   GET  /v1/health/:store_id              store health
%%%   GET  /v1/server-info/:store_id         version + integrity info
%%%   GET  /v1/stores                        list store instances
%%%   GET  /v1/stores/:store_id              store instances
%%%   *    /v1/stores/:store_id/streams/*    StreamService (sync)
%%%   *    /v1/stores/:store_id/events/*     cross-stream indexed reads
%%%   POST /v1/stores/:store_id/dcb/context  DCB context read
%%%   POST /v1/stores/:store_id/dcb/append   DCB conditional append
%%%   GET  /admin/[...]                      static admin UI
-module(reckon_gateway_http_listener).

-export([child_spec/0]).

child_spec() ->
    Port   = http_port(),
    Routes = cowboy_router:compile([
        {'_', [
            %% Gateway health (no store_id)
            {"/v1/health",                   reckon_gateway_http_health, #{op => gateway}},
            %% Per-store health + info
            {"/v1/health/:store_id",         reckon_gateway_http_health, #{op => store}},
            {"/v1/server-info/:store_id",    reckon_gateway_http_health, #{op => server_info}},
            %% Store discovery
            {"/v1/stores",                   reckon_gateway_http_health, #{op => list_stores}},
            {"/v1/stores/:store_id",         reckon_gateway_http_health, #{op => get_store}},
            %% Stream list + delete
            {"/v1/stores/:store_id/streams",
             reckon_gateway_http_streams, #{op => list}},
            {"/v1/stores/:store_id/streams/:stream_id",
             reckon_gateway_http_streams, #{op => stream}},
            %% Events on a stream (append / read)
            {"/v1/stores/:store_id/streams/:stream_id/events",
             reckon_gateway_http_streams, #{op => events}},
            %% Stream version
            {"/v1/stores/:store_id/streams/:stream_id/version",
             reckon_gateway_http_streams, #{op => version}},
            %% Cross-stream indexed reads
            {"/v1/stores/:store_id/events/by-type",
             reckon_gateway_http_streams, #{op => by_type}},
            {"/v1/stores/:store_id/events/by-tags",
             reckon_gateway_http_streams, #{op => by_tags}},
            {"/v1/stores/:store_id/events/by-metadata",
             reckon_gateway_http_streams, #{op => by_metadata}},
            {"/v1/stores/:store_id/events/global",
             reckon_gateway_http_streams, #{op => global}},
            %% DCB
            {"/v1/stores/:store_id/dcb/context",
             reckon_gateway_http_dcb, #{op => context}},
            {"/v1/stores/:store_id/dcb/append",
             reckon_gateway_http_dcb, #{op => append}},
            %% Admin UI — served from priv/static/admin/
            {"/admin/[...]",
             cowboy_static, {priv_dir, reckon_gateway, "static/admin"}}
        ]}
    ]),
    ranch:child_spec(
        reckon_gateway_http,
        ranch_tcp,
        [{port, Port}],
        cowboy_clear,
        #{env => #{dispatch => Routes}}
    ).

%%====================================================================
%% Internal
%%====================================================================

http_port() ->
    case application:get_env(reckon_gateway, http_port) of
        {ok, P} when is_integer(P) -> P;
        {ok, B} when is_binary(B)  -> binary_to_integer(B);
        {ok, L} when is_list(L)    ->
            case catch list_to_integer(L) of
                P when is_integer(P) -> P;
                _                    -> from_os()
            end;
        _ -> from_os()
    end.

from_os() ->
    case os:getenv("RECKON_GATEWAY_HTTP_PORT") of
        false -> 8080;
        ""    -> 8080;
        V     ->
            try list_to_integer(V)
            catch _:_ -> 8080
            end
    end.
