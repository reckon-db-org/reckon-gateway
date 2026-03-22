%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.CausationService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_causation_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpcbox/include/grpcbox.hrl").

-define(is_ctx(Ctx), is_tuple(Ctx) andalso element(1, Ctx) =:= ctx).

-define(SERVICE, 'reckon.gateway.v1.CausationService').
-define(PROTO_MODULE, 'reckon_causation_pb').
-define(MARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Input, Output, MessageType), #grpcbox_def{service=?SERVICE,
                                                      message_type=MessageType,
                                                      marshal_fun=?MARSHAL_FUN(Input),
                                                      unmarshal_fun=?UNMARSHAL_FUN(Output)}).

%% @doc Unary RPC
-spec get_effects(reckon_causation_pb:causation_request()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_effects(Input) ->
    get_effects(ctx:new(), Input, #{}).

-spec get_effects(ctx:t() | reckon_causation_pb:causation_request(), reckon_causation_pb:causation_request() | grpcbox_client:options()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_effects(Ctx, Input) when ?is_ctx(Ctx) ->
    get_effects(Ctx, Input, #{});
get_effects(Input, Options) ->
    get_effects(ctx:new(), Input, Options).

-spec get_effects(ctx:t(), reckon_causation_pb:causation_request(), grpcbox_client:options()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_effects(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.CausationService/GetEffects">>, Input, ?DEF(causation_request, causation_response, <<"reckon.gateway.v1.CausationRequest">>), Options).

%% @doc Unary RPC
-spec get_cause(reckon_causation_pb:causation_request()) ->
    {ok, reckon_causation_pb:single_event_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_cause(Input) ->
    get_cause(ctx:new(), Input, #{}).

-spec get_cause(ctx:t() | reckon_causation_pb:causation_request(), reckon_causation_pb:causation_request() | grpcbox_client:options()) ->
    {ok, reckon_causation_pb:single_event_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_cause(Ctx, Input) when ?is_ctx(Ctx) ->
    get_cause(Ctx, Input, #{});
get_cause(Input, Options) ->
    get_cause(ctx:new(), Input, Options).

-spec get_cause(ctx:t(), reckon_causation_pb:causation_request(), grpcbox_client:options()) ->
    {ok, reckon_causation_pb:single_event_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_cause(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.CausationService/GetCause">>, Input, ?DEF(causation_request, single_event_response, <<"reckon.gateway.v1.CausationRequest">>), Options).

%% @doc Unary RPC
-spec get_causation_chain(reckon_causation_pb:causation_request()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_causation_chain(Input) ->
    get_causation_chain(ctx:new(), Input, #{}).

-spec get_causation_chain(ctx:t() | reckon_causation_pb:causation_request(), reckon_causation_pb:causation_request() | grpcbox_client:options()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_causation_chain(Ctx, Input) when ?is_ctx(Ctx) ->
    get_causation_chain(Ctx, Input, #{});
get_causation_chain(Input, Options) ->
    get_causation_chain(ctx:new(), Input, Options).

-spec get_causation_chain(ctx:t(), reckon_causation_pb:causation_request(), grpcbox_client:options()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_causation_chain(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.CausationService/GetCausationChain">>, Input, ?DEF(causation_request, causation_response, <<"reckon.gateway.v1.CausationRequest">>), Options).

%% @doc Unary RPC
-spec get_correlated(reckon_causation_pb:correlation_request()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_correlated(Input) ->
    get_correlated(ctx:new(), Input, #{}).

-spec get_correlated(ctx:t() | reckon_causation_pb:correlation_request(), reckon_causation_pb:correlation_request() | grpcbox_client:options()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_correlated(Ctx, Input) when ?is_ctx(Ctx) ->
    get_correlated(Ctx, Input, #{});
get_correlated(Input, Options) ->
    get_correlated(ctx:new(), Input, Options).

-spec get_correlated(ctx:t(), reckon_causation_pb:correlation_request(), grpcbox_client:options()) ->
    {ok, reckon_causation_pb:causation_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_correlated(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.CausationService/GetCorrelated">>, Input, ?DEF(correlation_request, causation_response, <<"reckon.gateway.v1.CorrelationRequest">>), Options).

%% @doc Unary RPC
-spec build_causation_graph(reckon_causation_pb:causation_request()) ->
    {ok, reckon_causation_pb:causation_graph_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
build_causation_graph(Input) ->
    build_causation_graph(ctx:new(), Input, #{}).

-spec build_causation_graph(ctx:t() | reckon_causation_pb:causation_request(), reckon_causation_pb:causation_request() | grpcbox_client:options()) ->
    {ok, reckon_causation_pb:causation_graph_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
build_causation_graph(Ctx, Input) when ?is_ctx(Ctx) ->
    build_causation_graph(Ctx, Input, #{});
build_causation_graph(Input, Options) ->
    build_causation_graph(ctx:new(), Input, Options).

-spec build_causation_graph(ctx:t(), reckon_causation_pb:causation_request(), grpcbox_client:options()) ->
    {ok, reckon_causation_pb:causation_graph_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
build_causation_graph(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.CausationService/BuildCausationGraph">>, Input, ?DEF(causation_request, causation_graph_response, <<"reckon.gateway.v1.CausationRequest">>), Options).

