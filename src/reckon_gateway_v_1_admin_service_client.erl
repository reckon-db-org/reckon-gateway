%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.AdminService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_admin_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpc/include/grpc.hrl").

-define(SERVICE, 'reckon.gateway.v1.AdminService').
-define(PROTO_MODULE, 'reckon_admin_pb').
-define(MARSHAL(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Path, Req, Resp, MessageType),
        #{path => Path,
          service =>?SERVICE,
          message_type => MessageType,
          marshal => ?MARSHAL(Req),
          unmarshal => ?UNMARSHAL(Resp)}).

-spec get_store_stats(reckon_admin_pb:store_stats_request())
    -> {ok, reckon_admin_pb:store_stats_response(), grpc:metadata()}
     | {error, term()}.
get_store_stats(Req) ->
    get_store_stats(Req, #{}, #{}).

-spec get_store_stats(reckon_admin_pb:store_stats_request(), grpc:options())
    -> {ok, reckon_admin_pb:store_stats_response(), grpc:metadata()}
     | {error, term()}.
get_store_stats(Req, Options) ->
    get_store_stats(Req, #{}, Options).

-spec get_store_stats(reckon_admin_pb:store_stats_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:store_stats_response(), grpc:metadata()}
     | {error, term()}.
get_store_stats(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/GetStoreStats">>,
                           store_stats_request, store_stats_response, <<"reckon.gateway.v1.StoreStatsRequest">>),
                      Req, Metadata, Options).

-spec get_stream_info(reckon_admin_pb:stream_info_request())
    -> {ok, reckon_admin_pb:stream_info_response(), grpc:metadata()}
     | {error, term()}.
get_stream_info(Req) ->
    get_stream_info(Req, #{}, #{}).

-spec get_stream_info(reckon_admin_pb:stream_info_request(), grpc:options())
    -> {ok, reckon_admin_pb:stream_info_response(), grpc:metadata()}
     | {error, term()}.
get_stream_info(Req, Options) ->
    get_stream_info(Req, #{}, Options).

-spec get_stream_info(reckon_admin_pb:stream_info_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:stream_info_response(), grpc:metadata()}
     | {error, term()}.
get_stream_info(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/GetStreamInfo">>,
                           stream_info_request, stream_info_response, <<"reckon.gateway.v1.StreamInfoRequest">>),
                      Req, Metadata, Options).

-spec get_event_type_summary(reckon_admin_pb:event_type_summary_request())
    -> {ok, reckon_admin_pb:event_type_summary_response(), grpc:metadata()}
     | {error, term()}.
get_event_type_summary(Req) ->
    get_event_type_summary(Req, #{}, #{}).

-spec get_event_type_summary(reckon_admin_pb:event_type_summary_request(), grpc:options())
    -> {ok, reckon_admin_pb:event_type_summary_response(), grpc:metadata()}
     | {error, term()}.
get_event_type_summary(Req, Options) ->
    get_event_type_summary(Req, #{}, Options).

-spec get_event_type_summary(reckon_admin_pb:event_type_summary_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:event_type_summary_response(), grpc:metadata()}
     | {error, term()}.
get_event_type_summary(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/GetEventTypeSummary">>,
                           event_type_summary_request, event_type_summary_response, <<"reckon.gateway.v1.EventTypeSummaryRequest">>),
                      Req, Metadata, Options).

-spec scavenge(reckon_admin_pb:scavenge_request())
    -> {ok, reckon_admin_pb:scavenge_response(), grpc:metadata()}
     | {error, term()}.
scavenge(Req) ->
    scavenge(Req, #{}, #{}).

-spec scavenge(reckon_admin_pb:scavenge_request(), grpc:options())
    -> {ok, reckon_admin_pb:scavenge_response(), grpc:metadata()}
     | {error, term()}.
scavenge(Req, Options) ->
    scavenge(Req, #{}, Options).

-spec scavenge(reckon_admin_pb:scavenge_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:scavenge_response(), grpc:metadata()}
     | {error, term()}.
scavenge(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/Scavenge">>,
                           scavenge_request, scavenge_response, <<"reckon.gateway.v1.ScavengeRequest">>),
                      Req, Metadata, Options).

-spec scavenge_matching(reckon_admin_pb:scavenge_matching_request())
    -> {ok, reckon_admin_pb:scavenge_matching_response(), grpc:metadata()}
     | {error, term()}.
scavenge_matching(Req) ->
    scavenge_matching(Req, #{}, #{}).

-spec scavenge_matching(reckon_admin_pb:scavenge_matching_request(), grpc:options())
    -> {ok, reckon_admin_pb:scavenge_matching_response(), grpc:metadata()}
     | {error, term()}.
scavenge_matching(Req, Options) ->
    scavenge_matching(Req, #{}, Options).

-spec scavenge_matching(reckon_admin_pb:scavenge_matching_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:scavenge_matching_response(), grpc:metadata()}
     | {error, term()}.
scavenge_matching(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/ScavengeMatching">>,
                           scavenge_matching_request, scavenge_matching_response, <<"reckon.gateway.v1.ScavengeMatchingRequest">>),
                      Req, Metadata, Options).

-spec scavenge_dry_run(reckon_admin_pb:scavenge_request())
    -> {ok, reckon_admin_pb:scavenge_response(), grpc:metadata()}
     | {error, term()}.
scavenge_dry_run(Req) ->
    scavenge_dry_run(Req, #{}, #{}).

-spec scavenge_dry_run(reckon_admin_pb:scavenge_request(), grpc:options())
    -> {ok, reckon_admin_pb:scavenge_response(), grpc:metadata()}
     | {error, term()}.
scavenge_dry_run(Req, Options) ->
    scavenge_dry_run(Req, #{}, Options).

-spec scavenge_dry_run(reckon_admin_pb:scavenge_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:scavenge_response(), grpc:metadata()}
     | {error, term()}.
scavenge_dry_run(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/ScavengeDryRun">>,
                           scavenge_request, scavenge_response, <<"reckon.gateway.v1.ScavengeRequest">>),
                      Req, Metadata, Options).

-spec create_link(reckon_admin_pb:create_link_request())
    -> {ok, reckon_admin_pb:create_link_response(), grpc:metadata()}
     | {error, term()}.
create_link(Req) ->
    create_link(Req, #{}, #{}).

-spec create_link(reckon_admin_pb:create_link_request(), grpc:options())
    -> {ok, reckon_admin_pb:create_link_response(), grpc:metadata()}
     | {error, term()}.
create_link(Req, Options) ->
    create_link(Req, #{}, Options).

-spec create_link(reckon_admin_pb:create_link_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:create_link_response(), grpc:metadata()}
     | {error, term()}.
create_link(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/CreateLink">>,
                           create_link_request, create_link_response, <<"reckon.gateway.v1.CreateLinkRequest">>),
                      Req, Metadata, Options).

-spec delete_link(reckon_admin_pb:delete_link_request())
    -> {ok, reckon_admin_pb:delete_link_response(), grpc:metadata()}
     | {error, term()}.
delete_link(Req) ->
    delete_link(Req, #{}, #{}).

-spec delete_link(reckon_admin_pb:delete_link_request(), grpc:options())
    -> {ok, reckon_admin_pb:delete_link_response(), grpc:metadata()}
     | {error, term()}.
delete_link(Req, Options) ->
    delete_link(Req, #{}, Options).

-spec delete_link(reckon_admin_pb:delete_link_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:delete_link_response(), grpc:metadata()}
     | {error, term()}.
delete_link(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/DeleteLink">>,
                           delete_link_request, delete_link_response, <<"reckon.gateway.v1.DeleteLinkRequest">>),
                      Req, Metadata, Options).

-spec get_link(reckon_admin_pb:get_link_request())
    -> {ok, reckon_admin_pb:link_info(), grpc:metadata()}
     | {error, term()}.
get_link(Req) ->
    get_link(Req, #{}, #{}).

-spec get_link(reckon_admin_pb:get_link_request(), grpc:options())
    -> {ok, reckon_admin_pb:link_info(), grpc:metadata()}
     | {error, term()}.
get_link(Req, Options) ->
    get_link(Req, #{}, Options).

-spec get_link(reckon_admin_pb:get_link_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:link_info(), grpc:metadata()}
     | {error, term()}.
get_link(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/GetLink">>,
                           get_link_request, link_info, <<"reckon.gateway.v1.GetLinkRequest">>),
                      Req, Metadata, Options).

-spec list_links(reckon_admin_pb:list_links_request())
    -> {ok, reckon_admin_pb:list_links_response(), grpc:metadata()}
     | {error, term()}.
list_links(Req) ->
    list_links(Req, #{}, #{}).

-spec list_links(reckon_admin_pb:list_links_request(), grpc:options())
    -> {ok, reckon_admin_pb:list_links_response(), grpc:metadata()}
     | {error, term()}.
list_links(Req, Options) ->
    list_links(Req, #{}, Options).

-spec list_links(reckon_admin_pb:list_links_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:list_links_response(), grpc:metadata()}
     | {error, term()}.
list_links(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/ListLinks">>,
                           list_links_request, list_links_response, <<"reckon.gateway.v1.ListLinksRequest">>),
                      Req, Metadata, Options).

-spec start_link(reckon_admin_pb:start_link_request())
    -> {ok, reckon_admin_pb:start_link_response(), grpc:metadata()}
     | {error, term()}.
start_link(Req) ->
    start_link(Req, #{}, #{}).

-spec start_link(reckon_admin_pb:start_link_request(), grpc:options())
    -> {ok, reckon_admin_pb:start_link_response(), grpc:metadata()}
     | {error, term()}.
start_link(Req, Options) ->
    start_link(Req, #{}, Options).

-spec start_link(reckon_admin_pb:start_link_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:start_link_response(), grpc:metadata()}
     | {error, term()}.
start_link(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/StartLink">>,
                           start_link_request, start_link_response, <<"reckon.gateway.v1.StartLinkRequest">>),
                      Req, Metadata, Options).

-spec stop_link(reckon_admin_pb:stop_link_request())
    -> {ok, reckon_admin_pb:stop_link_response(), grpc:metadata()}
     | {error, term()}.
stop_link(Req) ->
    stop_link(Req, #{}, #{}).

-spec stop_link(reckon_admin_pb:stop_link_request(), grpc:options())
    -> {ok, reckon_admin_pb:stop_link_response(), grpc:metadata()}
     | {error, term()}.
stop_link(Req, Options) ->
    stop_link(Req, #{}, Options).

-spec stop_link(reckon_admin_pb:stop_link_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:stop_link_response(), grpc:metadata()}
     | {error, term()}.
stop_link(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/StopLink">>,
                           stop_link_request, stop_link_response, <<"reckon.gateway.v1.StopLinkRequest">>),
                      Req, Metadata, Options).

-spec get_link_info(reckon_admin_pb:get_link_request())
    -> {ok, reckon_admin_pb:link_runtime_info(), grpc:metadata()}
     | {error, term()}.
get_link_info(Req) ->
    get_link_info(Req, #{}, #{}).

-spec get_link_info(reckon_admin_pb:get_link_request(), grpc:options())
    -> {ok, reckon_admin_pb:link_runtime_info(), grpc:metadata()}
     | {error, term()}.
get_link_info(Req, Options) ->
    get_link_info(Req, #{}, Options).

-spec get_link_info(reckon_admin_pb:get_link_request(), grpc:metadata(), grpc_client:options())
    -> {ok, reckon_admin_pb:link_runtime_info(), grpc:metadata()}
     | {error, term()}.
get_link_info(Req, Metadata, Options) ->
    grpc_client:unary(?DEF(<<"/reckon.gateway.v1.AdminService/GetLinkInfo">>,
                           get_link_request, link_runtime_info, <<"reckon.gateway.v1.GetLinkRequest">>),
                      Req, Metadata, Options).

