%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.StoresService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_stores_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.StoresService').
-define(PROTO_MODULE, 'reckon_stores_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec list_stores(reckon_stores_pb:list_stores_request())
    -> {ok, reckon_stores_pb:list_stores_response(), grpc:metadata()}
     | {error, term()}.
list_stores(Req) ->
    list_stores(Req, #{}, #{}).

-spec list_stores(reckon_stores_pb:list_stores_request(), grpc:options())
    -> {ok, reckon_stores_pb:list_stores_response(), grpc:metadata()}
     | {error, term()}.
list_stores(Req, Options) ->
    list_stores(Req, #{}, Options).

-spec list_stores(reckon_stores_pb:list_stores_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_stores_pb:list_stores_response(), grpc:metadata()}
     | {error, term()}.
list_stores(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StoresService/ListStores">>,
                           list_stores_request, list_stores_response, <<"reckon.gateway.v1.ListStoresRequest">>),
                      Req, Metadata, Options).

-spec get_store(reckon_stores_pb:get_store_request())
    -> {ok, reckon_stores_pb:get_store_response(), grpc:metadata()}
     | {error, term()}.
get_store(Req) ->
    get_store(Req, #{}, #{}).

-spec get_store(reckon_stores_pb:get_store_request(), grpc:options())
    -> {ok, reckon_stores_pb:get_store_response(), grpc:metadata()}
     | {error, term()}.
get_store(Req, Options) ->
    get_store(Req, #{}, Options).

-spec get_store(reckon_stores_pb:get_store_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_stores_pb:get_store_response(), grpc:metadata()}
     | {error, term()}.
get_store(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.StoresService/GetStore">>,
                           get_store_request, get_store_response, <<"reckon.gateway.v1.GetStoreRequest">>),
                      Req, Metadata, Options).

-spec watch_stores(grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
watch_stores(Options) ->
    watch_stores(#{}, Options).

-spec watch_stores(grpc:metadata(), grpc_client:options())
    -> {ok, grpc_client:grpcstream()}
     | {error, term()}.
watch_stores(Metadata, Options) ->
    grpc_client:open(?DEF(<<"/reckon.gateway.v1.StoresService/WatchStores">>,
                          watch_stores_request, store_event, <<"reckon.gateway.v1.WatchStoresRequest">>),
                     Metadata, Options).

