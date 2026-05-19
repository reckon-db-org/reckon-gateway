%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service reckon.gateway.v1.AdminService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_admin_service_bhvr).

-callback get_store_stats(reckon_admin_pb:store_stats_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:store_stats_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_stream_info(reckon_admin_pb:stream_info_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:stream_info_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_event_type_summary(reckon_admin_pb:event_type_summary_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:event_type_summary_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback scavenge(reckon_admin_pb:scavenge_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:scavenge_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback scavenge_matching(reckon_admin_pb:scavenge_matching_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:scavenge_matching_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback scavenge_dry_run(reckon_admin_pb:scavenge_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:scavenge_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback create_link(reckon_admin_pb:create_link_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:create_link_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback delete_link(reckon_admin_pb:delete_link_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:delete_link_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_link(reckon_admin_pb:get_link_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:link_info(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback list_links(reckon_admin_pb:list_links_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:list_links_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback start_link(reckon_admin_pb:start_link_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:start_link_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback stop_link(reckon_admin_pb:stop_link_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:stop_link_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_link_info(reckon_admin_pb:get_link_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:link_runtime_info(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback reload_catalogue(reckon_admin_pb:reload_catalogue_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:reload_catalogue_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

-callback get_catalogue_status(reckon_admin_pb:get_catalogue_status_request(), grpc:metadata())
    -> {ok, reckon_admin_pb:get_catalogue_status_response(), grpc:metadata()}
     | {error, grpc_stream:error_response()}.

