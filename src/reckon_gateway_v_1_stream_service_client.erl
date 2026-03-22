%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.StreamService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_stream_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpcbox/include/grpcbox.hrl").

-define(is_ctx(Ctx), is_tuple(Ctx) andalso element(1, Ctx) =:= ctx).

-define(SERVICE, 'reckon.gateway.v1.StreamService').
-define(PROTO_MODULE, 'reckon_streams_pb').
-define(MARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Input, Output, MessageType), #grpcbox_def{service=?SERVICE,
                                                      message_type=MessageType,
                                                      marshal_fun=?MARSHAL_FUN(Input),
                                                      unmarshal_fun=?UNMARSHAL_FUN(Output)}).

%% @doc Unary RPC
-spec append_events(reckon_streams_pb:append_events_request()) ->
    {ok, reckon_streams_pb:append_events_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
append_events(Input) ->
    append_events(ctx:new(), Input, #{}).

-spec append_events(ctx:t() | reckon_streams_pb:append_events_request(), reckon_streams_pb:append_events_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:append_events_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
append_events(Ctx, Input) when ?is_ctx(Ctx) ->
    append_events(Ctx, Input, #{});
append_events(Input, Options) ->
    append_events(ctx:new(), Input, Options).

-spec append_events(ctx:t(), reckon_streams_pb:append_events_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:append_events_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
append_events(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/AppendEvents">>, Input, ?DEF(append_events_request, append_events_response, <<"reckon.gateway.v1.AppendEventsRequest">>), Options).

%% @doc Unary RPC
-spec read_stream_forward(reckon_streams_pb:read_stream_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_stream_forward(Input) ->
    read_stream_forward(ctx:new(), Input, #{}).

-spec read_stream_forward(ctx:t() | reckon_streams_pb:read_stream_request(), reckon_streams_pb:read_stream_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_stream_forward(Ctx, Input) when ?is_ctx(Ctx) ->
    read_stream_forward(Ctx, Input, #{});
read_stream_forward(Input, Options) ->
    read_stream_forward(ctx:new(), Input, Options).

-spec read_stream_forward(ctx:t(), reckon_streams_pb:read_stream_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_stream_forward(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/ReadStreamForward">>, Input, ?DEF(read_stream_request, read_stream_response, <<"reckon.gateway.v1.ReadStreamRequest">>), Options).

%% @doc Unary RPC
-spec read_stream_backward(reckon_streams_pb:read_stream_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_stream_backward(Input) ->
    read_stream_backward(ctx:new(), Input, #{}).

-spec read_stream_backward(ctx:t() | reckon_streams_pb:read_stream_request(), reckon_streams_pb:read_stream_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_stream_backward(Ctx, Input) when ?is_ctx(Ctx) ->
    read_stream_backward(Ctx, Input, #{});
read_stream_backward(Input, Options) ->
    read_stream_backward(ctx:new(), Input, Options).

-spec read_stream_backward(ctx:t(), reckon_streams_pb:read_stream_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_stream_backward(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/ReadStreamBackward">>, Input, ?DEF(read_stream_request, read_stream_response, <<"reckon.gateway.v1.ReadStreamRequest">>), Options).

%% @doc 
-spec stream_events_forward(reckon_streams_pb:read_stream_request()) ->
    {ok, grpcbox_client:stream()} | grpcbox_stream:grpc_error_response() | {error, any()}.
stream_events_forward(Input) ->
    stream_events_forward(ctx:new(), Input, #{}).

-spec stream_events_forward(ctx:t() | reckon_streams_pb:read_stream_request(), reckon_streams_pb:read_stream_request() | grpcbox_client:options()) ->
    {ok, grpcbox_client:stream()} | grpcbox_stream:grpc_error_response() | {error, any()}.
stream_events_forward(Ctx, Input) when ?is_ctx(Ctx) ->
    stream_events_forward(Ctx, Input, #{});
stream_events_forward(Input, Options) ->
    stream_events_forward(ctx:new(), Input, Options).

-spec stream_events_forward(ctx:t(), reckon_streams_pb:read_stream_request(), grpcbox_client:options()) ->
    {ok, grpcbox_client:stream()} | grpcbox_stream:grpc_error_response() | {error, any()}.
stream_events_forward(Ctx, Input, Options) ->
    grpcbox_client:stream(Ctx, <<"/reckon.gateway.v1.StreamService/StreamEventsForward">>, Input, ?DEF(read_stream_request, recorded_event, <<"reckon.gateway.v1.ReadStreamRequest">>), Options).

%% @doc Unary RPC
-spec get_stream_version(reckon_streams_pb:get_stream_version_request()) ->
    {ok, reckon_streams_pb:get_stream_version_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_stream_version(Input) ->
    get_stream_version(ctx:new(), Input, #{}).

-spec get_stream_version(ctx:t() | reckon_streams_pb:get_stream_version_request(), reckon_streams_pb:get_stream_version_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:get_stream_version_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_stream_version(Ctx, Input) when ?is_ctx(Ctx) ->
    get_stream_version(Ctx, Input, #{});
get_stream_version(Input, Options) ->
    get_stream_version(ctx:new(), Input, Options).

-spec get_stream_version(ctx:t(), reckon_streams_pb:get_stream_version_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:get_stream_version_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_stream_version(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/GetStreamVersion">>, Input, ?DEF(get_stream_version_request, get_stream_version_response, <<"reckon.gateway.v1.GetStreamVersionRequest">>), Options).

%% @doc Unary RPC
-spec list_streams(reckon_streams_pb:list_streams_request()) ->
    {ok, reckon_streams_pb:list_streams_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_streams(Input) ->
    list_streams(ctx:new(), Input, #{}).

-spec list_streams(ctx:t() | reckon_streams_pb:list_streams_request(), reckon_streams_pb:list_streams_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:list_streams_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_streams(Ctx, Input) when ?is_ctx(Ctx) ->
    list_streams(Ctx, Input, #{});
list_streams(Input, Options) ->
    list_streams(ctx:new(), Input, Options).

-spec list_streams(ctx:t(), reckon_streams_pb:list_streams_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:list_streams_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_streams(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/ListStreams">>, Input, ?DEF(list_streams_request, list_streams_response, <<"reckon.gateway.v1.ListStreamsRequest">>), Options).

%% @doc Unary RPC
-spec delete_stream(reckon_streams_pb:delete_stream_request()) ->
    {ok, reckon_streams_pb:delete_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_stream(Input) ->
    delete_stream(ctx:new(), Input, #{}).

-spec delete_stream(ctx:t() | reckon_streams_pb:delete_stream_request(), reckon_streams_pb:delete_stream_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:delete_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_stream(Ctx, Input) when ?is_ctx(Ctx) ->
    delete_stream(Ctx, Input, #{});
delete_stream(Input, Options) ->
    delete_stream(ctx:new(), Input, Options).

-spec delete_stream(ctx:t(), reckon_streams_pb:delete_stream_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:delete_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_stream(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/DeleteStream">>, Input, ?DEF(delete_stream_request, delete_stream_response, <<"reckon.gateway.v1.DeleteStreamRequest">>), Options).

%% @doc Unary RPC
-spec read_by_event_types(reckon_streams_pb:read_by_event_types_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_by_event_types(Input) ->
    read_by_event_types(ctx:new(), Input, #{}).

-spec read_by_event_types(ctx:t() | reckon_streams_pb:read_by_event_types_request(), reckon_streams_pb:read_by_event_types_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_by_event_types(Ctx, Input) when ?is_ctx(Ctx) ->
    read_by_event_types(Ctx, Input, #{});
read_by_event_types(Input, Options) ->
    read_by_event_types(ctx:new(), Input, Options).

-spec read_by_event_types(ctx:t(), reckon_streams_pb:read_by_event_types_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_by_event_types(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/ReadByEventTypes">>, Input, ?DEF(read_by_event_types_request, read_stream_response, <<"reckon.gateway.v1.ReadByEventTypesRequest">>), Options).

%% @doc Unary RPC
-spec read_by_tags(reckon_streams_pb:read_by_tags_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_by_tags(Input) ->
    read_by_tags(ctx:new(), Input, #{}).

-spec read_by_tags(ctx:t() | reckon_streams_pb:read_by_tags_request(), reckon_streams_pb:read_by_tags_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_by_tags(Ctx, Input) when ?is_ctx(Ctx) ->
    read_by_tags(Ctx, Input, #{});
read_by_tags(Input, Options) ->
    read_by_tags(ctx:new(), Input, Options).

-spec read_by_tags(ctx:t(), reckon_streams_pb:read_by_tags_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_by_tags(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/ReadByTags">>, Input, ?DEF(read_by_tags_request, read_stream_response, <<"reckon.gateway.v1.ReadByTagsRequest">>), Options).

%% @doc Unary RPC
-spec read_all_global(reckon_streams_pb:read_all_global_request()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_all_global(Input) ->
    read_all_global(ctx:new(), Input, #{}).

-spec read_all_global(ctx:t() | reckon_streams_pb:read_all_global_request(), reckon_streams_pb:read_all_global_request() | grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_all_global(Ctx, Input) when ?is_ctx(Ctx) ->
    read_all_global(Ctx, Input, #{});
read_all_global(Input, Options) ->
    read_all_global(ctx:new(), Input, Options).

-spec read_all_global(ctx:t(), reckon_streams_pb:read_all_global_request(), grpcbox_client:options()) ->
    {ok, reckon_streams_pb:read_stream_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
read_all_global(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.StreamService/ReadAllGlobal">>, Input, ?DEF(read_all_global_request, read_stream_response, <<"reckon.gateway.v1.ReadAllGlobalRequest">>), Options).

