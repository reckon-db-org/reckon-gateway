%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.StreamService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_stream_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.StreamService').
-define(PROTO_MODULE, 'reckon_streams_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec append_events(reckon_streams_pb:append_events_request())
    -> {ok, reckon_streams_pb:append_events_response(), grpc:metadata()}
     | {error, term()}.
append_events(Req) ->
    append_events(Req, #{}, #{}).

-spec append_events(reckon_streams_pb:append_events_request(), grpc:options())
    -> {ok, reckon_streams_pb:append_events_response(), grpc:metadata()}
     | {error, term()}.
append_events(Req, Options) ->
    append_events(Req, #{}, Options).

-spec append_events(reckon_streams_pb:append_events_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:append_events_response(), grpc:metadata()}
     | {error, term()}.
append_events(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/AppendEvents">>,
                           append_events_request, append_events_response, <<"reckon.gateway.v1.AppendEventsRequest">>),
                      Req, Metadata, Options).

-spec read_stream_forward(reckon_streams_pb:read_stream_request())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_stream_forward(Req) ->
    read_stream_forward(Req, #{}, #{}).

-spec read_stream_forward(reckon_streams_pb:read_stream_request(), grpc:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_stream_forward(Req, Options) ->
    read_stream_forward(Req, #{}, Options).

-spec read_stream_forward(reckon_streams_pb:read_stream_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_stream_forward(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/ReadStreamForward">>,
                           read_stream_request, read_stream_response, <<"reckon.gateway.v1.ReadStreamRequest">>),
                      Req, Metadata, Options).

-spec read_stream_backward(reckon_streams_pb:read_stream_request())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_stream_backward(Req) ->
    read_stream_backward(Req, #{}, #{}).

-spec read_stream_backward(reckon_streams_pb:read_stream_request(), grpc:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_stream_backward(Req, Options) ->
    read_stream_backward(Req, #{}, Options).

-spec read_stream_backward(reckon_streams_pb:read_stream_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_stream_backward(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/ReadStreamBackward">>,
                           read_stream_request, read_stream_response, <<"reckon.gateway.v1.ReadStreamRequest">>),
                      Req, Metadata, Options).

-spec stream_events_forward(grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
stream_events_forward(Options) ->
    stream_events_forward(#{}, Options).

-spec stream_events_forward(grpc:metadata(), grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
stream_events_forward(Metadata, Options) ->
    grpc_client:open(?DEF(<<"/reckon.gateway.v1.StreamService/StreamEventsForward">>,
                          read_stream_request, recorded_event, <<"reckon.gateway.v1.ReadStreamRequest">>),
                     Metadata, Options).

-spec get_stream_version(reckon_streams_pb:get_stream_version_request())
    -> {ok, reckon_streams_pb:get_stream_version_response(), grpc:metadata()}
     | {error, term()}.
get_stream_version(Req) ->
    get_stream_version(Req, #{}, #{}).

-spec get_stream_version(reckon_streams_pb:get_stream_version_request(), grpc:options())
    -> {ok, reckon_streams_pb:get_stream_version_response(), grpc:metadata()}
     | {error, term()}.
get_stream_version(Req, Options) ->
    get_stream_version(Req, #{}, Options).

-spec get_stream_version(reckon_streams_pb:get_stream_version_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:get_stream_version_response(), grpc:metadata()}
     | {error, term()}.
get_stream_version(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/GetStreamVersion">>,
                           get_stream_version_request, get_stream_version_response, <<"reckon.gateway.v1.GetStreamVersionRequest">>),
                      Req, Metadata, Options).

-spec list_streams(reckon_streams_pb:list_streams_request())
    -> {ok, reckon_streams_pb:list_streams_response(), grpc:metadata()}
     | {error, term()}.
list_streams(Req) ->
    list_streams(Req, #{}, #{}).

-spec list_streams(reckon_streams_pb:list_streams_request(), grpc:options())
    -> {ok, reckon_streams_pb:list_streams_response(), grpc:metadata()}
     | {error, term()}.
list_streams(Req, Options) ->
    list_streams(Req, #{}, Options).

-spec list_streams(reckon_streams_pb:list_streams_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:list_streams_response(), grpc:metadata()}
     | {error, term()}.
list_streams(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/ListStreams">>,
                           list_streams_request, list_streams_response, <<"reckon.gateway.v1.ListStreamsRequest">>),
                      Req, Metadata, Options).

-spec delete_stream(reckon_streams_pb:delete_stream_request())
    -> {ok, reckon_streams_pb:delete_stream_response(), grpc:metadata()}
     | {error, term()}.
delete_stream(Req) ->
    delete_stream(Req, #{}, #{}).

-spec delete_stream(reckon_streams_pb:delete_stream_request(), grpc:options())
    -> {ok, reckon_streams_pb:delete_stream_response(), grpc:metadata()}
     | {error, term()}.
delete_stream(Req, Options) ->
    delete_stream(Req, #{}, Options).

-spec delete_stream(reckon_streams_pb:delete_stream_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:delete_stream_response(), grpc:metadata()}
     | {error, term()}.
delete_stream(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/DeleteStream">>,
                           delete_stream_request, delete_stream_response, <<"reckon.gateway.v1.DeleteStreamRequest">>),
                      Req, Metadata, Options).

-spec read_by_event_types(reckon_streams_pb:read_by_event_types_request())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_by_event_types(Req) ->
    read_by_event_types(Req, #{}, #{}).

-spec read_by_event_types(reckon_streams_pb:read_by_event_types_request(), grpc:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_by_event_types(Req, Options) ->
    read_by_event_types(Req, #{}, Options).

-spec read_by_event_types(reckon_streams_pb:read_by_event_types_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_by_event_types(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/ReadByEventTypes">>,
                           read_by_event_types_request, read_stream_response, <<"reckon.gateway.v1.ReadByEventTypesRequest">>),
                      Req, Metadata, Options).

-spec read_by_tags(reckon_streams_pb:read_by_tags_request())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_by_tags(Req) ->
    read_by_tags(Req, #{}, #{}).

-spec read_by_tags(reckon_streams_pb:read_by_tags_request(), grpc:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_by_tags(Req, Options) ->
    read_by_tags(Req, #{}, Options).

-spec read_by_tags(reckon_streams_pb:read_by_tags_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_by_tags(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/ReadByTags">>,
                           read_by_tags_request, read_stream_response, <<"reckon.gateway.v1.ReadByTagsRequest">>),
                      Req, Metadata, Options).

-spec read_all_global(reckon_streams_pb:read_all_global_request())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_all_global(Req) ->
    read_all_global(Req, #{}, #{}).

-spec read_all_global(reckon_streams_pb:read_all_global_request(), grpc:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_all_global(Req, Options) ->
    read_all_global(Req, #{}, Options).

-spec read_all_global(reckon_streams_pb:read_all_global_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, term()}.
read_all_global(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StreamService/ReadAllGlobal">>,
                           read_all_global_request, read_stream_response, <<"reckon.gateway.v1.ReadAllGlobalRequest">>),
                      Req, Metadata, Options).

