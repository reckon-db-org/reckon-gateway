%%% @doc Fleet-wide event-ingest rate for the admin dashboard.
%%%
%%% The gateway sits off the data path: parksim (and any other consumer)
%%% writes into each store's embedded reckon-db, not through the gateway.
%%% So the dispatch metrics (reckon_gateway_metrics) only ever see read
%%% traffic proxied *through* the gateway, which is near-zero at rest.
%%%
%%% To show the fleet's actual activity, this slice polls every catalogue
%%% store's `store_stats' (cheap aggregate — `total_events') on a timer,
%%% diffs the count against the previous sample, and derives events/s per
%%% store and fleet-wide, plus a sparkline series. The polling itself runs
%%% in a throwaway worker so a slow/unreachable store never blocks the
%%% gen_server (or `snapshot_json/0', which the SSE loop calls).
%%%
%%% Note: this DOES add recurring read load on the store BEAMs, and the
%%% `store_stats' dispatches show up in the dispatch metrics — both are
%%% intentional and honest.
-module(reckon_gateway_fleet_ingest).

-behaviour(gen_server).

-export([child_spec/0, start_link/0, snapshot_json/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-ifdef(TEST).
%% Pure rate-derivation surface, exercised by the eunit suite (the live
%% path needs real stores to sample).
-export([initial_state/0, apply_sample/3, build_snapshot/1]).
-endif.

-define(POLL_MS, 5_000).
-define(WINDOW, 60).   %% samples kept for the fleet sparkline

-record(state, {
    %% store_id => {count_at_last_sample, ts_ms}
    prev   = #{} :: #{atom() => {non_neg_integer(), integer()}},
    %% store_id => latest total_events
    counts = #{} :: #{atom() => non_neg_integer()},
    %% store_id => events/s from the last diff
    rates  = #{} :: #{atom() => number()},
    %% fleet events/s, newest-first, capped at ?WINDOW
    series = []  :: [number()]
}).

-ifdef(TEST).
initial_state() -> #state{}.
-endif.

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
%% gen_server
%%====================================================================

init([]) ->
    erlang:send_after(?POLL_MS, self(), poll),
    {ok, #state{}}.

handle_call(snapshot_json, _From, State) ->
    {reply, build_snapshot(State), State};
handle_call(_Msg, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast({sample, Sample, Ts}, State) ->
    {noreply, apply_sample(Sample, Ts, State)};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(poll, State) ->
    Self = self(),
    Stores = store_ids(),
    %% Read all stores in a throwaway process; the gen_server stays
    %% responsive even if a store_stats dispatch stalls.
    spawn(fun() ->
        Ts = erlang:system_time(millisecond),
        Sample = [{Id, read_count(Id)} || Id <- Stores],
        gen_server:cast(Self, {sample, Sample, Ts})
    end),
    erlang:send_after(?POLL_MS, self(), poll),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal
%%====================================================================

store_ids() ->
    lists:usort([maps:get(store_id, E)
                 || E <- reckon_gateway_catalogue:list_entries()]).

read_count(StoreId) ->
    try reckon_gateway_dispatch:call(store_stats, [StoreId]) of
        {ok, Stats} -> {ok, maps:get(total_events, Stats, 0)};
        _           -> error
    catch _:_ -> error
    end.

%% Fold a fresh sample into state: per-store events/s from the delta
%% against the previous count, fleet rate = sum of per-store rates. Only
%% stores in this sample survive, so stores that leave the catalogue drop
%% out on their own.
apply_sample(Sample, Ts, #state{prev = Prev0, counts = OldCounts} = State) ->
    Ctx = {Prev0, OldCounts},
    {Counts, Rates, Prev} = lists:foldl(
        fun({Id, Read}, Acc) -> fold_store(Id, Read, Ts, Ctx, Acc) end,
        {#{}, #{}, #{}}, Sample),
    FleetRate = lists:sum(maps:values(Rates)),
    Series = lists:sublist([round1(FleetRate) | State#state.series], ?WINDOW),
    State#state{prev = Prev, counts = Counts, rates = Rates, series = Series}.

fold_store(Id, {ok, Count}, Ts, {Prev0, _OldCounts}, {Counts, Rates, Prev}) ->
    Rate = case maps:find(Id, Prev0) of
        {ok, {PrevCount, PrevTs}} -> per_sec(Count - PrevCount, Ts - PrevTs);
        error                     -> 0.0
    end,
    {Counts#{Id => Count}, Rates#{Id => Rate}, Prev#{Id => {Count, Ts}}};
fold_store(Id, error, _Ts, {Prev0, OldCounts}, {Counts, Rates, Prev}) ->
    %% Unreachable this tick: keep the last known count so the tenant
    %% doesn't flicker out of the fleet total, report 0/s (we couldn't
    %% measure it), and carry prev forward so the next successful read
    %% diffs against the right baseline.
    Counts1 = carry_count(Id, maps:find(Id, OldCounts), Counts),
    Prev1   = carry_prev(Id, maps:find(Id, Prev0), Prev),
    {Counts1, Rates#{Id => 0.0}, Prev1}.

carry_count(Id, {ok, Count}, Counts) -> Counts#{Id => Count};
carry_count(_Id, error, Counts)      -> Counts.

carry_prev(Id, {ok, Entry}, Prev) -> Prev#{Id => Entry};
carry_prev(_Id, error, Prev)      -> Prev.

%% Deltas below zero mean a scavenge/prune shrank the store — report 0,
%% not a negative rate.
per_sec(Delta, ElapsedMs) when Delta > 0, ElapsedMs > 0 ->
    round1(Delta * 1000 / ElapsedMs);
per_sec(_, _) ->
    0.0.

build_snapshot(#state{counts = Counts, rates = Rates, series = Series}) ->
    PerStore = [#{<<"store_id">>  => atom_to_binary(Id, utf8),
                  <<"events">>    => Count,
                  <<"per_s">>     => maps:get(Id, Rates, 0.0)}
                || {Id, Count} <- lists:sort(maps:to_list(Counts))],
    #{
        <<"total_events">> => lists:sum(maps:values(Counts)),
        <<"events_per_s">> => round1(lists:sum(maps:values(Rates))),
        <<"per_store">>    => PerStore,
        <<"series">>       => lists:reverse(Series),
        <<"poll_ms">>      => ?POLL_MS,
        <<"window_s">>     => ?WINDOW * (?POLL_MS div 1000),
        <<"timestamp_ms">> => erlang:system_time(millisecond)
    }.

round1(F) -> erlang:round(F * 10) / 10.
