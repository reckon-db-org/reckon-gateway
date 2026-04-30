%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.CausationService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_causation_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.CausationService').
-define(PROTO_MODULE, 'reckon_causation_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec get_effects(reckon_causation_pb:causation_request())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_effects(Req) ->
    get_effects(Req, #{}, #{}).

-spec get_effects(reckon_causation_pb:causation_request(), grpc:options())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_effects(Req, Options) ->
    get_effects(Req, #{}, Options).

-spec get_effects(reckon_causation_pb:causation_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_effects(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.CausationService/GetEffects">>,
                           causation_request, causation_response, <<"reckon.gateway.v1.CausationRequest">>),
                      Req, Metadata, Options).

-spec get_cause(reckon_causation_pb:causation_request())
    -> {ok, reckon_causation_pb:single_event_response(), grpc:metadata()}
     | {error, term()}.
get_cause(Req) ->
    get_cause(Req, #{}, #{}).

-spec get_cause(reckon_causation_pb:causation_request(), grpc:options())
    -> {ok, reckon_causation_pb:single_event_response(), grpc:metadata()}
     | {error, term()}.
get_cause(Req, Options) ->
    get_cause(Req, #{}, Options).

-spec get_cause(reckon_causation_pb:causation_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_causation_pb:single_event_response(), grpc:metadata()}
     | {error, term()}.
get_cause(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.CausationService/GetCause">>,
                           causation_request, single_event_response, <<"reckon.gateway.v1.CausationRequest">>),
                      Req, Metadata, Options).

-spec get_causation_chain(reckon_causation_pb:causation_request())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_causation_chain(Req) ->
    get_causation_chain(Req, #{}, #{}).

-spec get_causation_chain(reckon_causation_pb:causation_request(), grpc:options())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_causation_chain(Req, Options) ->
    get_causation_chain(Req, #{}, Options).

-spec get_causation_chain(reckon_causation_pb:causation_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_causation_chain(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.CausationService/GetCausationChain">>,
                           causation_request, causation_response, <<"reckon.gateway.v1.CausationRequest">>),
                      Req, Metadata, Options).

-spec get_correlated(reckon_causation_pb:correlation_request())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_correlated(Req) ->
    get_correlated(Req, #{}, #{}).

-spec get_correlated(reckon_causation_pb:correlation_request(), grpc:options())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_correlated(Req, Options) ->
    get_correlated(Req, #{}, Options).

-spec get_correlated(reckon_causation_pb:correlation_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_causation_pb:causation_response(), grpc:metadata()}
     | {error, term()}.
get_correlated(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.CausationService/GetCorrelated">>,
                           correlation_request, causation_response, <<"reckon.gateway.v1.CorrelationRequest">>),
                      Req, Metadata, Options).

-spec build_causation_graph(reckon_causation_pb:causation_request())
    -> {ok, reckon_causation_pb:causation_graph_response(), grpc:metadata()}
     | {error, term()}.
build_causation_graph(Req) ->
    build_causation_graph(Req, #{}, #{}).

-spec build_causation_graph(reckon_causation_pb:causation_request(), grpc:options())
    -> {ok, reckon_causation_pb:causation_graph_response(), grpc:metadata()}
     | {error, term()}.
build_causation_graph(Req, Options) ->
    build_causation_graph(Req, #{}, Options).

-spec build_causation_graph(reckon_causation_pb:causation_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_causation_pb:causation_graph_response(), grpc:metadata()}
     | {error, term()}.
build_causation_graph(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.CausationService/BuildCausationGraph">>,
                           causation_request, causation_graph_response, <<"reckon.gateway.v1.CausationRequest">>),
                      Req, Metadata, Options).

