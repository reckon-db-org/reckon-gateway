%%% @doc Error-handling helpers for reckon-gateway gRPC services.
%%%
%%% Background: emqx/grpc-erl's unary handler interface only
%%% supports `{error, Code}' — see
%%% `_build/default/lib/grpc/src/grpc_stream.erl:264' (FIXME).
%%% The library hardcodes an empty `grpc-message' trailer, so we
%%% cannot deliver the underlying reason to the gRPC client over
%%% the wire. We MUST therefore log the reason server-side so
%%% `docker logs reckon-gateway' is useful for triage.
%%%
%%% Server-streaming RPCs (the 3-tuple `{Code, Message, Stream}'
%%% shape) DO carry a description through — `wrap_stream/3' uses
%%% that path.
-module(reckon_gateway_error).

-export([
    wrap/3,
    wrap_stream/3,
    log/3,
    format_reason/1
]).

%% @doc Log + return a 2-tuple error suitable for grpc-erl unary
%% handlers. The `Fn' atom identifies the gRPC operation (e.g.
%% `list_streams', `append_events') and shows up in the log line.
-spec wrap(atom(), binary(), term()) -> {error, binary()}.
wrap(Fn, Code, Reason) ->
    log(Fn, Code, Reason),
    {error, Code}.

%% @doc Log + return a 2-tuple `{Code, Message}' for server-streaming
%% handlers (grpc_stream's 3-tuple `{Code, Reason, Stream}' shape;
%% caller appends the `Stream' element itself).
-spec wrap_stream(atom(), binary(), term()) -> {binary(), binary()}.
wrap_stream(Fn, Code, Reason) ->
    log(Fn, Code, Reason),
    {Code, format_reason(Reason)}.

%% @doc Emit a warning log line for a handler-side failure.
-spec log(atom(), binary(), term()) -> ok.
log(Fn, Code, Reason) ->
    logger:warning(
        "gateway ~s failed: code=~s reason=~s",
        [Fn, Code, format_reason(Reason)]
    ).

%% @doc Render a dispatch/handler reason term as a printable binary.
%% Known shapes get short prose; unknowns fall through to `~p'.
-spec format_reason(term()) -> binary().
format_reason(store_unknown) ->
    <<"store not in catalogue">>;
format_reason(cluster_unavailable) ->
    <<"no healthy member in cluster">>;
format_reason({rpc_failed, Node, {'EXIT', {undef, [{M, F, Args, _} | _]}}}) ->
    iolist_to_binary(
        io_lib:format("undef ~p:~p/~p on ~p (likely dep-version mismatch)",
                      [M, F, length(Args), Node])
    );
format_reason({rpc_failed, Node, {nodedown, _}}) ->
    iolist_to_binary(io_lib:format("node down: ~p", [Node]));
format_reason({rpc_failed, Node, timeout}) ->
    iolist_to_binary(io_lib:format("rpc timeout on ~p", [Node]));
format_reason({rpc_failed, Node, Reason}) ->
    iolist_to_binary(io_lib:format("rpc to ~p failed: ~p", [Node, Reason]));
format_reason(Other) ->
    iolist_to_binary(io_lib:format("~p", [Other])).
