#!/usr/bin/env bash
# Verify the three load-bearing assumptions of the catalogue-mode
# design (see plans/DESIGN_RECKON_GATEWAY_CATALOGUE.md). Run from
# a fresh BEAM whose DEFAULT cookie is wrong on purpose, so any
# successful connection proves per-peer cookie scoping is doing
# the work — not the BEAM's default.
#
# Spikes:
#   1. erlang:set_cookie(Node, Cookie) + net_adm:ping/1 succeeds
#      from a BEAM whose default cookie differs.
#   2. pg state on the remote (parksim) BEAM is reachable via
#      rpc:call.
#   3. reckon_db_store_registry:list_stores/0 on the remote BEAM
#      returns the expected store_id list.
#
# Usage:
#   scripts/verify-catalogue-assumptions.sh                          # default: parksim_entry2exit@192.168.1.10
#   scripts/verify-catalogue-assumptions.sh <node> <cookie>          # any cluster member
#
# Requirements: `erl` on PATH; epmd reachable on the target host.

set -uo pipefail

TARGET_NODE="${1:-parksim_entry2exit@192.168.1.10}"
TARGET_COOKIE="${2:-tKcKQnLjuoAVECwP9TcfA2AQJvA6QzL4ZcnykOihzQw}"
SPIKE_NAME="catalogue-spike-$$@192.168.1.100"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/catalogue_spike.erl" <<'EOF'
-module(catalogue_spike).
-export([run/2]).

run(Target, CookieStr) ->
    Cookie = list_to_atom(CookieStr),
    io:format("=== environment ===~n", []),
    io:format("  my node:       ~p~n", [node()]),
    io:format("  my cookie:     ~p (wrong on purpose)~n", [erlang:get_cookie()]),
    io:format("  target node:   ~p~n", [Target]),
    io:format("  target cookie: ~p (will be set per-peer)~n", [Cookie]),

    io:format("~n=== Spike 1: per-peer cookie + connect ===~n", []),
    erlang:set_cookie(Target, Cookie),
    Pong = net_adm:ping(Target),
    io:format("  net_adm:ping/1 = ~p (expect: pong)~n", [Pong]),
    io:format("  my cookie AFTER: ~p (should be unchanged)~n", [erlang:get_cookie()]),
    io:format("  nodes() = ~p~n", [nodes()]),

    io:format("~n=== Spike 2: pg state on remote BEAM ===~n", []),
    PgScope = parksim_entry2exit,
    case rpc:call(Target, pg, which_groups, [PgScope]) of
        {badrpc, R2} -> io:format("  pg:which_groups failed: ~p~n", [R2]);
        Groups       -> io:format("  pg:which_groups(~p) = ~p~n", [PgScope, Groups])
    end,

    io:format("~n=== Spike 3: reckon_db_store_registry on remote BEAM ===~n", []),
    case rpc:call(Target, reckon_db_store_registry, list_stores, []) of
        {badrpc, R3} -> io:format("  list_stores failed: ~p~n", [R3]);
        Stores       -> io:format("  reckon_db_store_registry:list_stores() = ~p~n", [Stores])
    end,

    io:format("~n=== bonus: loaded apps on remote BEAM ===~n", []),
    case rpc:call(Target, application, which_applications, []) of
        {badrpc, R4} ->
            io:format("  which_applications failed: ~p~n", [R4]);
        Loaded ->
            Filtered = [N || {N, _, _} <- Loaded,
                             lists:prefix("reckon", atom_to_list(N))
                             orelse lists:prefix("evoq", atom_to_list(N))
                             orelse lists:prefix("parksim", atom_to_list(N))
                             orelse lists:prefix("hecate", atom_to_list(N))],
            io:format("  reckon/evoq/parksim/hecate apps: ~p~n", [Filtered])
    end,

    io:format("~n=== bonus: reckon_db_store_registry module path on remote ===~n", []),
    case rpc:call(Target, code, which, [reckon_db_store_registry]) of
        {badrpc, _} = R5 -> io:format("  code:which failed: ~p~n", [R5]);
        Path             -> io:format("  reckon_db_store_registry beam: ~p~n", [Path])
    end,

    halt(0).
EOF

cd "$WORK"
erlc catalogue_spike.erl

erl -name "$SPIKE_NAME" -setcookie spike_default_WRONG_cookie -noshell \
    -pa "$WORK" \
    -eval "catalogue_spike:run('$TARGET_NODE', \"$TARGET_COOKIE\"), halt(0)."
