%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.StreamService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_stream_service_bhvr).

-callback append_events(reckon_streams_pb:append_events_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:append_events_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback read_stream_forward(reckon_streams_pb:read_stream_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback read_stream_backward(reckon_streams_pb:read_stream_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback stream_events_forward(grpc_stream:stream(), grpc:metadata())
    -> {ok, grpc_stream:stream()}.

-callback get_stream_version(reckon_streams_pb:get_stream_version_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:get_stream_version_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback list_streams(reckon_streams_pb:list_streams_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:list_streams_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback delete_stream(reckon_streams_pb:delete_stream_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:delete_stream_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback read_by_event_types(reckon_streams_pb:read_by_event_types_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback read_by_tags(reckon_streams_pb:read_by_tags_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback read_all_global(reckon_streams_pb:read_all_global_request(), grpc:metadata())
    -> {ok, reckon_streams_pb:read_stream_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

