%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.StoresService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_stores_service_bhvr).

-callback list_stores(reckon_stores_pb:list_stores_request(), grpc:metadata())
    -> {ok, reckon_stores_pb:list_stores_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_store(reckon_stores_pb:get_store_request(), grpc:metadata())
    -> {ok, reckon_stores_pb:get_store_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback watch_stores(grpc_stream:stream(), grpc:metadata())
    -> {ok, grpc_stream:stream()}.

