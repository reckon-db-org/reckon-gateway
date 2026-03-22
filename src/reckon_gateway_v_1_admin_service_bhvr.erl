%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.AdminService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_admin_service_bhvr).

%% Unary RPC
-callback get_store_stats(ctx:t(), reckon_admin_pb:store_stats_request()) ->
    {ok, reckon_admin_pb:store_stats_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_stream_info(ctx:t(), reckon_admin_pb:stream_info_request()) ->
    {ok, reckon_admin_pb:stream_info_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_event_type_summary(ctx:t(), reckon_admin_pb:event_type_summary_request()) ->
    {ok, reckon_admin_pb:event_type_summary_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback list_stores(ctx:t(), reckon_admin_pb:list_stores_request()) ->
    {ok, reckon_admin_pb:list_stores_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback scavenge(ctx:t(), reckon_admin_pb:scavenge_request()) ->
    {ok, reckon_admin_pb:scavenge_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback scavenge_matching(ctx:t(), reckon_admin_pb:scavenge_matching_request()) ->
    {ok, reckon_admin_pb:scavenge_matching_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback scavenge_dry_run(ctx:t(), reckon_admin_pb:scavenge_request()) ->
    {ok, reckon_admin_pb:scavenge_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback create_link(ctx:t(), reckon_admin_pb:create_link_request()) ->
    {ok, reckon_admin_pb:create_link_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback delete_link(ctx:t(), reckon_admin_pb:delete_link_request()) ->
    {ok, reckon_admin_pb:delete_link_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_link(ctx:t(), reckon_admin_pb:get_link_request()) ->
    {ok, reckon_admin_pb:link_info(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback list_links(ctx:t(), reckon_admin_pb:list_links_request()) ->
    {ok, reckon_admin_pb:list_links_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback start_link(ctx:t(), reckon_admin_pb:start_link_request()) ->
    {ok, reckon_admin_pb:start_link_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback stop_link(ctx:t(), reckon_admin_pb:stop_link_request()) ->
    {ok, reckon_admin_pb:stop_link_response(), ctx:t()} | grpcbox_stream:grpc_error_response().

%% Unary RPC
-callback get_link_info(ctx:t(), reckon_admin_pb:get_link_request()) ->
    {ok, reckon_admin_pb:link_runtime_info(), ctx:t()} | grpcbox_stream:grpc_error_response().

