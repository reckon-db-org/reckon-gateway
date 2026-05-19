#!/usr/bin/env bash
# Check whether reckon_db_store_registry on the LIVE reckon-gateway
# cluster (the embedded-mode one running on the laptop + beam00..03)
# actually contains stores. This isolates the question: "is the
# registry broken everywhere, or only on parksim BEAMs (where no
# store is started)?"
set -uo pipefail

TARGET_NODE='reckon_gateway@192.168.1.100'
TARGET_COOKIE='tKcKQnLjuoAVECwP9TcfA2AQJvA6QzL4ZcnykOihzQw'
SPIKE_NAME="gateway-probe-$$@192.168.1.100"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/gw_probe.erl" <<'EOF'
-module(gw_probe).
-export([run/2]).

run(Target, CookieStr) ->
    erlang:set_cookie(Target, list_to_atom(CookieStr)),
    pong = net_adm:ping(Target),

    io:format("=== reckon-gateway (embedded mode) ===~n", []),
    io:format("  node: ~p~n", [Target]),

    io:format("~n=== reckon_db_store_registry:list_stores() ===~n", []),
    case rpc:call(Target, reckon_db_store_registry, list_stores, []) of
        {badrpc, R} -> io:format("  badrpc: ~p~n", [R]);
        Stores      -> io:format("  ~p~n", [Stores])
    end,

    io:format("~n=== reckon_db_sup children ===~n", []),
    case rpc:call(Target, supervisor, which_children, [reckon_db_sup]) of
        {badrpc, R2} -> io:format("  badrpc: ~p~n", [R2]);
        Kids         -> io:format("  ~p~n", [Kids])
    end,

    halt(0).
EOF

cd "$WORK"
erlc gw_probe.erl

erl -name "$SPIKE_NAME" -setcookie spike_default_WRONG -noshell \
    -pa "$WORK" \
    -eval "gw_probe:run('$TARGET_NODE', \"$TARGET_COOKIE\"), halt(0)."
