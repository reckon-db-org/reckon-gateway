%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.DcbService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_dcb_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.DcbService').
-define(PROTO_MODULE, 'reckon_dcb_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec append_if_no_tag_matches(reckon_dcb_pb:append_if_no_tag_matches_request())
    -> {ok, reckon_dcb_pb:append_if_no_tag_matches_response(), grpc:metadata()}
     | {error, term()}.
append_if_no_tag_matches(Req) ->
    append_if_no_tag_matches(Req, #{}, #{}).

-spec append_if_no_tag_matches(reckon_dcb_pb:append_if_no_tag_matches_request(), grpc:options())
    -> {ok, reckon_dcb_pb:append_if_no_tag_matches_response(), grpc:metadata()}
     | {error, term()}.
append_if_no_tag_matches(Req, Options) ->
    append_if_no_tag_matches(Req, #{}, Options).

-spec append_if_no_tag_matches(reckon_dcb_pb:append_if_no_tag_matches_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_dcb_pb:append_if_no_tag_matches_response(), grpc:metadata()}
     | {error, term()}.
append_if_no_tag_matches(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.DcbService/AppendIfNoTagMatches">>,
                           append_if_no_tag_matches_request, append_if_no_tag_matches_response, <<"reckon.gateway.v1.AppendIfNoTagMatchesRequest">>),
                      Req, Metadata, Options).

-spec read_dcb_context(reckon_dcb_pb:read_dcb_context_request())
    -> {ok, reckon_dcb_pb:read_dcb_context_response(), grpc:metadata()}
     | {error, term()}.
read_dcb_context(Req) ->
    read_dcb_context(Req, #{}, #{}).

-spec read_dcb_context(reckon_dcb_pb:read_dcb_context_request(), grpc:options())
    -> {ok, reckon_dcb_pb:read_dcb_context_response(), grpc:metadata()}
     | {error, term()}.
read_dcb_context(Req, Options) ->
    read_dcb_context(Req, #{}, Options).

-spec read_dcb_context(reckon_dcb_pb:read_dcb_context_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_dcb_pb:read_dcb_context_response(), grpc:metadata()}
     | {error, term()}.
read_dcb_context(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.DcbService/ReadDcbContext">>,
                           read_dcb_context_request, read_dcb_context_response, <<"reckon.gateway.v1.ReadDcbContextRequest">>),
                      Req, Metadata, Options).

-spec ccc_read_by_payload(reckon_dcb_pb:ccc_read_by_payload_request())
    -> {ok, reckon_dcb_pb:ccc_read_by_payload_response(), grpc:metadata()}
     | {error, term()}.
ccc_read_by_payload(Req) ->
    ccc_read_by_payload(Req, #{}, #{}).

-spec ccc_read_by_payload(reckon_dcb_pb:ccc_read_by_payload_request(), grpc:options())
    -> {ok, reckon_dcb_pb:ccc_read_by_payload_response(), grpc:metadata()}
     | {error, term()}.
ccc_read_by_payload(Req, Options) ->
    ccc_read_by_payload(Req, #{}, Options).

-spec ccc_read_by_payload(reckon_dcb_pb:ccc_read_by_payload_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_dcb_pb:ccc_read_by_payload_response(), grpc:metadata()}
     | {error, term()}.
ccc_read_by_payload(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.DcbService/CccReadByPayload">>,
                           ccc_read_by_payload_request, ccc_read_by_payload_response, <<"reckon.gateway.v1.CccReadByPayloadRequest">>),
                      Req, Metadata, Options).

-spec ccc_read_by_payload_hash(reckon_dcb_pb:ccc_read_by_payload_hash_request())
    -> {ok, reckon_dcb_pb:ccc_read_by_payload_hash_response(), grpc:metadata()}
     | {error, term()}.
ccc_read_by_payload_hash(Req) ->
    ccc_read_by_payload_hash(Req, #{}, #{}).

-spec ccc_read_by_payload_hash(reckon_dcb_pb:ccc_read_by_payload_hash_request(), grpc:options())
    -> {ok, reckon_dcb_pb:ccc_read_by_payload_hash_response(), grpc:metadata()}
     | {error, term()}.
ccc_read_by_payload_hash(Req, Options) ->
    ccc_read_by_payload_hash(Req, #{}, Options).

-spec ccc_read_by_payload_hash(reckon_dcb_pb:ccc_read_by_payload_hash_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_dcb_pb:ccc_read_by_payload_hash_response(), grpc:metadata()}
     | {error, term()}.
ccc_read_by_payload_hash(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.DcbService/CccReadByPayloadHash">>,
                           ccc_read_by_payload_hash_request, ccc_read_by_payload_hash_response, <<"reckon.gateway.v1.CccReadByPayloadHashRequest">>),
                      Req, Metadata, Options).

