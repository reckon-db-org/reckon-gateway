%%% @doc Server-Sent Events endpoint for live gateway/cluster status.
%%%
%%% GET /v1/admin/events
%%%
%%% Streams named SSE events to the browser admin UI:
%%%
%%%   event: status
%%%   data: {"node":"...","catalogue_size":N,"clusters":[...],
%%%          "stores":[{...,"cluster":{leader,quorum,status}}],
%%%          "timestamp_ms":N}
%%%
%%%   event: store_announced
%%%   data: {"store_id":"...","cluster_id":"...","node":"...","mode":"..."}
%%%
%%%   event: store_retired
%%%   data: {"store_id":"...","cluster_id":"..."}
%%%
%%% On connect:    subscribe to reckon_gateway_catalogue, push initial status.
%%% Every 10s:     push a fresh status snapshot (catches cluster health drift).
%%% On catalogue event: push the named event then a fresh status snapshot.
%%% On disconnect: unsubscribe and terminate cleanly.
-module(reckon_gateway_http_sse).

-behaviour(cowboy_loop).

-export([init/2, info/3, terminate/3]).

-define(KEEPALIVE_MS, 10_000).
-define(STATUS_DEBOUNCE_MS, 250).

%%====================================================================
%% cowboy_loop callbacks
%%====================================================================

init(Req0, _Opts) ->
    Req = cowboy_req:stream_reply(200, #{
        <<"content-type">>      => <<"text/event-stream">>,
        <<"cache-control">>     => <<"no-cache">>,
        <<"x-accel-buffering">> => <<"no">>,
        <<"access-control-allow-origin">> => <<"*">>
    }, Req0),
    reckon_gateway_catalogue:subscribe(self()),
    push_status(Req),
    schedule_keepalive(),
    {cowboy_loop, Req, #{status_scheduled => false}}.

info({store_event, announced, Entry}, Req, State) ->
    push_event(<<"store_announced">>, entry_to_json(Entry), Req),
    {ok, Req, schedule_status(State)};

info({store_event, retired, Entry}, Req, State) ->
    push_event(<<"store_retired">>, entry_to_json(Entry), Req),
    {ok, Req, schedule_status(State)};

info(flush_status, Req, State) ->
    %% Coalesced status push after a burst of store events (see
    %% schedule_status/1). Each push now probes every cluster store for
    %% leader/quorum, so we never fire more than one per debounce window.
    push_status(Req),
    {ok, Req, State#{status_scheduled => false}};

info(keepalive, Req, State) ->
    %% Comment frame keeps the connection alive through proxies.
    cowboy_req:stream_body(<<": keepalive\n\n">>, nofin, Req),
    push_status(Req),
    schedule_keepalive(),
    {ok, Req, State};

info(_Msg, Req, State) ->
    {ok, Req, State}.

terminate(_Reason, _Req, _State) ->
    reckon_gateway_catalogue:unsubscribe(self()),
    ok.

%%====================================================================
%% Internal
%%====================================================================

push_status(Req) ->
    Snapshot = reckon_gateway_catalogue:status(),
    push_event(<<"status">>, json:encode(status_to_json(Snapshot)), Req).

push_event(Name, JsonData, Req) ->
    cowboy_req:stream_body(
        [<<"event: ">>, Name, <<"\ndata: ">>, JsonData, <<"\n\n">>],
        nofin, Req).

schedule_keepalive() ->
    erlang:send_after(?KEEPALIVE_MS, self(), keepalive).

%% Debounce status pushes triggered by store events: at most one probe
%% sweep per window, coalescing a burst of announces/retires into a
%% single enriched snapshot.
schedule_status(#{status_scheduled := true} = State) ->
    State;
schedule_status(State) ->
    erlang:send_after(?STATUS_DEBOUNCE_MS, self(), flush_status),
    State#{status_scheduled => true}.

%%--------------------------------------------------------------------

status_to_json(#{catalogue_size := Size, clusters := Clusters}) ->
    #{
        <<"node">>           => atom_to_binary(node(), utf8),
        <<"catalogue_size">> => Size,
        <<"clusters">>       => [cluster_to_json(C) || C <- Clusters],
        <<"stores">>         => reckon_gateway_http_health:live_stores(),
        <<"timestamp_ms">>   => erlang:system_time(millisecond)
    }.

cluster_to_json(#{cluster_id   := Id,
                  members      := Members,
                  store_count  := SC,
                  status       := Status,
                  last_refresh := LR}) ->
    #{
        <<"cluster_id">>   => atom_to_binary(Id, utf8),
        <<"members">>      => [atom_to_binary(M, utf8) || M <- Members],
        <<"store_count">>  => SC,
        <<"status">>       => atom_to_binary(Status, utf8),
        <<"last_refresh">> => case LR of undefined -> null; _ -> LR end
    }.

entry_to_json(Entry) ->
    json:encode(#{
        <<"store_id">>   => bin(maps:get(store_id,   Entry, <<>>)),
        <<"cluster_id">> => bin(maps:get(cluster_id, Entry, <<>>)),
        <<"node">>       => bin(maps:get(node,        Entry, <<>>)),
        <<"mode">>       => bin(maps:get(mode,        Entry, <<>>))
    }).

bin(V) when is_atom(V)   -> atom_to_binary(V, utf8);
bin(V) when is_binary(V) -> V;
bin(V)                   -> iolist_to_binary(io_lib:format("~p", [V])).
