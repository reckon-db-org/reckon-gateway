%%% @doc Live throughput/latency metrics for the admin dashboard.
%%%
%%% Attaches a telemetry handler to the gateway's dispatch + catalogue
%%% events (see reckon_gateway_telemetry.hrl) and keeps them in a cheap,
%%% always-on accumulator:
%%%
%%%   - cumulative counters (calls, errors, store announce/retire),
%%%     per-op and per-error-reason breakdowns, in a public ETS table
%%%     that the inline telemetry handler bumps with atomic
%%%     `ets:update_counter' (no gen_server round-trip on the hot path);
%%%   - a ring of the last ?WINDOW one-second buckets, advanced by this
%%%     gen_server's 1s timer, for per-second rates and sparklines.
%%%
%%% `snapshot_json/0' returns a JSON-ready map the SSE endpoint pushes as
%%% a `metrics' event. Durations arrive in microseconds and are reported
%%% in milliseconds.
-module(reckon_gateway_metrics).

-behaviour(gen_server).

-include("reckon_gateway_telemetry.hrl").

-export([child_spec/0, start_link/0, snapshot_json/0, handle_telemetry/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TAB, ?MODULE).
-define(HANDLER_ID, reckon_gateway_metrics_handler).
-define(WINDOW, 60).       %% seconds of per-second history (sparklines)
-define(RATE_WINDOW, 5).   %% buckets averaged for the "per second" figure
-define(TICK_MS, 1000).

-record(bucket, {calls = 0 :: non_neg_integer(),
                 errors = 0 :: non_neg_integer(),
                 dur_us = 0 :: non_neg_integer()}).

-record(state, {ring = [] :: [#bucket{}]}).

%%====================================================================
%% API
%%====================================================================

child_spec() ->
    #{id       => ?MODULE,
      start    => {?MODULE, start_link, []},
      restart  => permanent,
      shutdown => 5000,
      type     => worker,
      modules  => [?MODULE]}.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec snapshot_json() -> map().
snapshot_json() ->
    gen_server:call(?MODULE, snapshot_json).

%%====================================================================
%% Telemetry handler (runs inline in the emitting process — keep cheap)
%%====================================================================

handle_telemetry(Event, Measurements, Meta, _Config) ->
    %% Never let a metrics bump crash the caller or make telemetry
    %% detach the handler; accounting is best-effort.
    catch record(Event, Measurements, Meta),
    ok.

record(?GW_DISPATCH_STOP, #{duration := D}, Meta) ->
    bump_call(D, maps:get(op, Meta, unknown));
record(?GW_DISPATCH_ERROR, #{duration := D}, Meta) ->
    bump_call(D, maps:get(op, Meta, unknown)),
    incr(errors_total),
    incr(cur_errors),
    incr({reason, maps:get(reason, Meta, unknown)});
record(?GW_STORE_ANNOUNCED, _, _) ->
    incr(store_announced);
record(?GW_STORE_RETIRED, _, _) ->
    incr(store_retired);
record(_, _, _) ->
    ok.

bump_call(DurationUs, Op) ->
    incr(calls_total),
    incr(cur_calls),
    add(cur_dur_us, DurationUs),
    incr({op, Op}).

incr(Key) -> add(Key, 1).

add(Key, N) -> ets:update_counter(?TAB, Key, N, {Key, 0}).

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    ets:new(?TAB, [named_table, public, set, {write_concurrency, true}]),
    reckon_gateway_telemetry:attach(?HANDLER_ID,
                                    fun ?MODULE:handle_telemetry/4, #{}),
    erlang:send_after(?TICK_MS, self(), tick),
    {ok, #state{ring = []}}.

handle_call(snapshot_json, _From, State) ->
    {reply, build_snapshot(State#state.ring), State};
handle_call(_Msg, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, #state{ring = Ring} = State) ->
    Bucket = #bucket{calls  = take(cur_calls),
                     errors = take(cur_errors),
                     dur_us = take(cur_dur_us)},
    NewRing = lists:sublist([Bucket | Ring], ?WINDOW),
    erlang:send_after(?TICK_MS, self(), tick),
    {noreply, State#state{ring = NewRing}};
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    _ = telemetry:detach(?HANDLER_ID),
    ok.

%%====================================================================
%% Internal
%%====================================================================

%% Atomic read-and-reset of a per-second accumulator: take removes the
%% key (returning its value); the next bump re-creates it from the
%% default. A bump racing the take simply lands in the next bucket.
take(Key) ->
    case ets:take(?TAB, Key) of
        [{_, V}] -> V;
        []       -> 0
    end.

lookup(Key) ->
    case ets:lookup(?TAB, Key) of
        [{_, V}] -> V;
        []       -> 0
    end.

build_snapshot(Ring) ->
    %% Ring is newest-first; series is oldest-first for left-to-right
    %% sparkline rendering.
    Recent      = lists:sublist(Ring, ?RATE_WINDOW),
    RecentSecs  = max(length(Recent), 1),
    RecentCalls = lists:sum([C || #bucket{calls = C} <- Recent]),
    RecentErrs  = lists:sum([E || #bucket{errors = E} <- Recent]),
    WindowCalls = lists:sum([C || #bucket{calls = C} <- Ring]),
    WindowDurUs = lists:sum([D || #bucket{dur_us = D} <- Ring]),
    CallsTotal  = lookup(calls_total),
    ErrorsTotal = lookup(errors_total),
    #{
        <<"calls_total">>     => CallsTotal,
        <<"errors_total">>    => ErrorsTotal,
        <<"calls_per_s">>     => round1(RecentCalls / RecentSecs),
        <<"errors_per_s">>    => round1(RecentErrs / RecentSecs),
        <<"error_rate_pct">>  => pct(ErrorsTotal, CallsTotal),
        <<"avg_latency_ms">>  => avg_ms(WindowDurUs, WindowCalls),
        <<"store_announced">> => lookup(store_announced),
        <<"store_retired">>   => lookup(store_retired),
        <<"by_op">>           => top_pairs({op, '_'}, <<"op">>),
        <<"by_reason">>       => top_pairs({reason, '_'}, <<"reason">>),
        <<"calls_series">>    => [C || #bucket{calls = C}  <- lists:reverse(Ring)],
        <<"errors_series">>   => [E || #bucket{errors = E} <- lists:reverse(Ring)],
        <<"window_s">>        => ?WINDOW,
        <<"timestamp_ms">>    => erlang:system_time(millisecond)
    }.

%% Top labelled counters (per-op / per-reason), highest first, capped.
top_pairs({Tag, '_'}, LabelKey) ->
    Pairs = ets:match_object(?TAB, {{Tag, '_'}, '_'}),
    Sorted = lists:sort(fun({_, A}, {_, B}) -> A >= B end, Pairs),
    [#{LabelKey => label_bin(L), <<"count">> => N}
     || {{Tag2, L}, N} <- lists:sublist(Sorted, 8), Tag2 =:= Tag].

label_bin(L) when is_atom(L)   -> atom_to_binary(L, utf8);
label_bin(L) when is_binary(L) -> L;
label_bin(L)                   -> iolist_to_binary(io_lib:format("~p", [L])).

pct(_, 0)     -> 0.0;
pct(Err, All) -> round1(Err * 100 / All).

avg_ms(_, 0)         -> 0.0;
avg_ms(DurUs, Calls) -> round1((DurUs / Calls) / 1000).

round1(F) -> erlang:round(F * 10) / 10.
