#!/usr/bin/env bash
# Third probe in the catalogue-readiness spike series: now that we
# know parksim doesn't materialise reckon-db stores, see what evoq
# IS doing. If aggregates are alive but events vanish to ETS,
# lazyreckon can never see them. Spike to confirm.
set -uo pipefail

TARGET_NODE="${1:-parksim_entry2exit@192.168.1.10}"
TARGET_COOKIE="${2:-tKcKQnLjuoAVECwP9TcfA2AQJvA6QzL4ZcnykOihzQw}"
SPIKE_NAME="evoq-probe-$$@192.168.1.100"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/evoq_probe.erl" <<'EOF'
-module(evoq_probe).
-export([run/2]).

run(Target, CookieStr) ->
    erlang:set_cookie(Target, list_to_atom(CookieStr)),
    pong = net_adm:ping(Target),

    io:format("=== evoq aggregate registry ===~n", []),
    case rpc:call(Target, ets, info, [evoq_aggregate_registry]) of
        {badrpc, R} -> io:format("  badrpc: ~p~n", [R]);
        undefined -> io:format("  ETS evoq_aggregate_registry: undefined~n", []);
        Info -> io:format("  ETS info: ~p~n", [Info])
    end,

    io:format("~n=== ETS evoq_aggregate_registry contents (first 5) ===~n", []),
    case rpc:call(Target, ets, tab2list, [evoq_aggregate_registry]) of
        {badrpc, R2} -> io:format("  badrpc: ~p~n", [R2]);
        Rows ->
            Sample = lists:sublist(Rows, 5),
            io:format("  count: ~p~n", [length(Rows)]),
            io:format("  sample: ~p~n", [Sample])
    end,

    io:format("~n=== reckon_evoq config ===~n", []),
    case rpc:call(Target, application, get_all_env, [reckon_evoq]) of
        {badrpc, R3} -> io:format("  badrpc: ~p~n", [R3]);
        Env3 -> io:format("  ~p~n", [Env3])
    end,

    io:format("~n=== evoq_event_router state ===~n", []),
    case rpc:call(Target, sys, get_state, [evoq_event_router]) of
        {badrpc, R4} -> io:format("  badrpc: ~p~n", [R4]);
        State4 ->
            %% Trim — state can be large.
            io:format("  ~P~n", [State4, 8])
    end,

    io:format("~n=== evoq_checkpoint_store_ets contents (first 5) ===~n", []),
    case rpc:call(Target, ets, tab2list, [evoq_checkpoint_store_ets]) of
        {badrpc, R5} -> io:format("  badrpc: ~p~n", [R5]);
        Rows5 ->
            Sample5 = lists:sublist(Rows5, 5),
            io:format("  count: ~p~n", [length(Rows5)]),
            io:format("  sample: ~p~n", [Sample5])
    end,

    io:format("~n=== look for an evoq store backend module ===~n", []),
    %% reckon_evoq is supposed to be the adapter; let's see its modules.
    case rpc:call(Target, application, get_key, [reckon_evoq, modules]) of
        {badrpc, R6} -> io:format("  badrpc: ~p~n", [R6]);
        Mods -> io:format("  reckon_evoq modules: ~p~n", [Mods])
    end,

    halt(0).
EOF

cd "$WORK"
erlc evoq_probe.erl

erl -name "$SPIKE_NAME" -setcookie spike_default_WRONG -noshell \
    -pa "$WORK" \
    -eval "evoq_probe:run('$TARGET_NODE', \"$TARGET_COOKIE\"), halt(0)."
