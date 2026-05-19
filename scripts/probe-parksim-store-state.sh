#!/usr/bin/env bash
# Follow-up probe to verify-catalogue-assumptions.sh: when Spike 3
# returned an empty store registry, dig into the parksim BEAM to
# see whether any reckon_db_store process is running at all, and
# what alternative APIs might expose the configured store_id.
set -uo pipefail

TARGET_NODE="${1:-parksim_entry2exit@192.168.1.10}"
TARGET_COOKIE="${2:-tKcKQnLjuoAVECwP9TcfA2AQJvA6QzL4ZcnykOihzQw}"
SPIKE_NAME="store-probe-$$@192.168.1.100"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/store_probe.erl" <<'EOF'
-module(store_probe).
-export([run/2]).

run(Target, CookieStr) ->
    erlang:set_cookie(Target, list_to_atom(CookieStr)),
    pong = net_adm:ping(Target),

    io:format("=== registered names on remote BEAM (filtered) ===~n", []),
    Names = rpc:call(Target, erlang, registered, []),
    Relevant = [N || N <- Names,
                     S <- [atom_to_list(N)],
                     lists:prefix("reckon", S)
                     orelse string:str(S, "store") > 0
                     orelse lists:prefix("evoq", S)],
    io:format("  ~p~n", [Relevant]),

    io:format("~n=== reckon_db top supervisor children ===~n", []),
    case rpc:call(Target, supervisor, which_children, [reckon_db_sup]) of
        {badrpc, R1} -> io:format("  badrpc: ~p~n", [R1]);
        Kids         -> io:format("  ~p~n", [Kids])
    end,

    io:format("~n=== reckon_db:list_stores/0 (top-level API) ===~n", []),
    case rpc:call(Target, reckon_db, list_stores, []) of
        {badrpc, R2} -> io:format("  badrpc: ~p~n", [R2]);
        Other        -> io:format("  ~p~n", [Other])
    end,

    io:format("~n=== reckon_db_store_registry:list_stores_on_node(Target) ===~n", []),
    case rpc:call(Target, reckon_db_store_registry, list_stores_on_node, [Target]) of
        {badrpc, R3} -> io:format("  badrpc: ~p~n", [R3]);
        Other2       -> io:format("  ~p~n", [Other2])
    end,

    io:format("~n=== reckon_gater_api exports (what we can rpc) ===~n", []),
    case rpc:call(Target, reckon_gater_api, module_info, [exports]) of
        {badrpc, R4} -> io:format("  badrpc: ~p~n", [R4]);
        Exports      -> io:format("  ~p~n", [Exports])
    end,

    io:format("~n=== reckon_db_store registered name? (atom) ===~n", []),
    case rpc:call(Target, erlang, whereis, [parksim_entry2exit_store]) of
        {badrpc, R5} -> io:format("  badrpc: ~p~n", [R5]);
        undefined    -> io:format("  whereis(parksim_entry2exit_store) = undefined~n", []);
        Pid          -> io:format("  whereis(parksim_entry2exit_store) = ~p~n", [Pid])
    end,

    io:format("~n=== evoq apps loaded + their event store config ===~n", []),
    case rpc:call(Target, application, get_all_env, [evoq]) of
        {badrpc, R6} -> io:format("  evoq env badrpc: ~p~n", [R6]);
        EvoqEnv      -> io:format("  evoq env: ~p~n", [EvoqEnv])
    end,
    case rpc:call(Target, application, get_all_env, [hecate_parksim_entry2exit]) of
        {badrpc, R7} -> io:format("  parksim env badrpc: ~p~n", [R7]);
        ParksimEnv   -> io:format("  parksim env: ~p~n", [ParksimEnv])
    end,

    halt(0).
EOF

cd "$WORK"
erlc store_probe.erl

erl -name "$SPIKE_NAME" -setcookie spike_default_WRONG -noshell \
    -pa "$WORK" \
    -eval "store_probe:run('$TARGET_NODE', \"$TARGET_COOKIE\"), halt(0)."
