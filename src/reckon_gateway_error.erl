%%% @doc Error-handling helpers for reckon-gateway gRPC services.
%%%
%%% Background: a unary handler that returns `{error, Code}' sends an
%%% empty `grpc-message' trailer; the vendored grpc-erl also accepts
%%% `{error, Code, Message}' (vendor/grpc/src/grpc_stream.erl). Store
%%% reasons can name nodes and internals, so they stay off the wire and
%%% are logged server-side, which keeps `docker logs reckon-gateway'
%%% useful for triage. The one reason that goes to the client is a
%%% refused stream id: its message is the rule the id broke, which is
%%% all the caller needs to fix it (reckon-gater#5).
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
%%
%% A refused stream id is the caller's to fix, whichever operation it
%% reached: it is always 3 (InvalidArgument), and the rule travels as the
%% grpc-message.
-spec wrap(atom(), binary(), term()) -> {error, binary()} | {error, binary(), binary()}.
wrap(Fn, _Code, {invalid_stream_id, _, _} = Reason) ->
    log(Fn, <<"3">>, Reason),
    {error, <<"3">>, format_reason(Reason)};
wrap(Fn, _Code, {invalid_stream_id, _, _, _} = Reason) ->
    log(Fn, <<"3">>, Reason),
    {error, <<"3">>, format_reason(Reason)};
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
format_reason({invalid_stream_id, _Reason, _StreamId, Rule}) ->
    Rule;
format_reason({invalid_stream_id, Reason, _StreamId}) ->
    %% A store older than reckon-db 5.11.14 sends no rule; gater has it.
    reckon_gater_stream_id:explain(Reason);
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
