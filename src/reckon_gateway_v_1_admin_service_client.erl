%%%-------------------------------------------------------------------
%% @doc Client module for grpc service reckon.gateway.v1.AdminService.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(reckon_gateway_v_1_admin_service_client).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("grpcbox/include/grpcbox.hrl").

-define(is_ctx(Ctx), is_tuple(Ctx) andalso element(1, Ctx) =:= ctx).

-define(SERVICE, 'reckon.gateway.v1.AdminService').
-define(PROTO_MODULE, 'reckon_admin_pb').
-define(MARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:encode_msg(I, T) end).
-define(UNMARSHAL_FUN(T), fun(I) -> ?PROTO_MODULE:decode_msg(I, T) end).
-define(DEF(Input, Output, MessageType), #grpcbox_def{service=?SERVICE,
                                                      message_type=MessageType,
                                                      marshal_fun=?MARSHAL_FUN(Input),
                                                      unmarshal_fun=?UNMARSHAL_FUN(Output)}).

%% @doc Unary RPC
-spec get_store_stats(reckon_admin_pb:store_stats_request()) ->
    {ok, reckon_admin_pb:store_stats_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_store_stats(Input) ->
    get_store_stats(ctx:new(), Input, #{}).

-spec get_store_stats(ctx:t() | reckon_admin_pb:store_stats_request(), reckon_admin_pb:store_stats_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:store_stats_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_store_stats(Ctx, Input) when ?is_ctx(Ctx) ->
    get_store_stats(Ctx, Input, #{});
get_store_stats(Input, Options) ->
    get_store_stats(ctx:new(), Input, Options).

-spec get_store_stats(ctx:t(), reckon_admin_pb:store_stats_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:store_stats_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_store_stats(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/GetStoreStats">>, Input, ?DEF(store_stats_request, store_stats_response, <<"reckon.gateway.v1.StoreStatsRequest">>), Options).

%% @doc Unary RPC
-spec get_stream_info(reckon_admin_pb:stream_info_request()) ->
    {ok, reckon_admin_pb:stream_info_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_stream_info(Input) ->
    get_stream_info(ctx:new(), Input, #{}).

-spec get_stream_info(ctx:t() | reckon_admin_pb:stream_info_request(), reckon_admin_pb:stream_info_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:stream_info_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_stream_info(Ctx, Input) when ?is_ctx(Ctx) ->
    get_stream_info(Ctx, Input, #{});
get_stream_info(Input, Options) ->
    get_stream_info(ctx:new(), Input, Options).

-spec get_stream_info(ctx:t(), reckon_admin_pb:stream_info_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:stream_info_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_stream_info(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/GetStreamInfo">>, Input, ?DEF(stream_info_request, stream_info_response, <<"reckon.gateway.v1.StreamInfoRequest">>), Options).

%% @doc Unary RPC
-spec get_event_type_summary(reckon_admin_pb:event_type_summary_request()) ->
    {ok, reckon_admin_pb:event_type_summary_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_event_type_summary(Input) ->
    get_event_type_summary(ctx:new(), Input, #{}).

-spec get_event_type_summary(ctx:t() | reckon_admin_pb:event_type_summary_request(), reckon_admin_pb:event_type_summary_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:event_type_summary_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_event_type_summary(Ctx, Input) when ?is_ctx(Ctx) ->
    get_event_type_summary(Ctx, Input, #{});
get_event_type_summary(Input, Options) ->
    get_event_type_summary(ctx:new(), Input, Options).

-spec get_event_type_summary(ctx:t(), reckon_admin_pb:event_type_summary_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:event_type_summary_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_event_type_summary(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/GetEventTypeSummary">>, Input, ?DEF(event_type_summary_request, event_type_summary_response, <<"reckon.gateway.v1.EventTypeSummaryRequest">>), Options).

%% @doc Unary RPC
-spec list_stores(reckon_admin_pb:list_stores_request()) ->
    {ok, reckon_admin_pb:list_stores_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_stores(Input) ->
    list_stores(ctx:new(), Input, #{}).

-spec list_stores(ctx:t() | reckon_admin_pb:list_stores_request(), reckon_admin_pb:list_stores_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:list_stores_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_stores(Ctx, Input) when ?is_ctx(Ctx) ->
    list_stores(Ctx, Input, #{});
list_stores(Input, Options) ->
    list_stores(ctx:new(), Input, Options).

-spec list_stores(ctx:t(), reckon_admin_pb:list_stores_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:list_stores_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_stores(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/ListStores">>, Input, ?DEF(list_stores_request, list_stores_response, <<"reckon.gateway.v1.ListStoresRequest">>), Options).

%% @doc Unary RPC
-spec scavenge(reckon_admin_pb:scavenge_request()) ->
    {ok, reckon_admin_pb:scavenge_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge(Input) ->
    scavenge(ctx:new(), Input, #{}).

-spec scavenge(ctx:t() | reckon_admin_pb:scavenge_request(), reckon_admin_pb:scavenge_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:scavenge_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge(Ctx, Input) when ?is_ctx(Ctx) ->
    scavenge(Ctx, Input, #{});
scavenge(Input, Options) ->
    scavenge(ctx:new(), Input, Options).

-spec scavenge(ctx:t(), reckon_admin_pb:scavenge_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:scavenge_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/Scavenge">>, Input, ?DEF(scavenge_request, scavenge_response, <<"reckon.gateway.v1.ScavengeRequest">>), Options).

%% @doc Unary RPC
-spec scavenge_matching(reckon_admin_pb:scavenge_matching_request()) ->
    {ok, reckon_admin_pb:scavenge_matching_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge_matching(Input) ->
    scavenge_matching(ctx:new(), Input, #{}).

-spec scavenge_matching(ctx:t() | reckon_admin_pb:scavenge_matching_request(), reckon_admin_pb:scavenge_matching_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:scavenge_matching_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge_matching(Ctx, Input) when ?is_ctx(Ctx) ->
    scavenge_matching(Ctx, Input, #{});
scavenge_matching(Input, Options) ->
    scavenge_matching(ctx:new(), Input, Options).

-spec scavenge_matching(ctx:t(), reckon_admin_pb:scavenge_matching_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:scavenge_matching_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge_matching(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/ScavengeMatching">>, Input, ?DEF(scavenge_matching_request, scavenge_matching_response, <<"reckon.gateway.v1.ScavengeMatchingRequest">>), Options).

%% @doc Unary RPC
-spec scavenge_dry_run(reckon_admin_pb:scavenge_request()) ->
    {ok, reckon_admin_pb:scavenge_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge_dry_run(Input) ->
    scavenge_dry_run(ctx:new(), Input, #{}).

-spec scavenge_dry_run(ctx:t() | reckon_admin_pb:scavenge_request(), reckon_admin_pb:scavenge_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:scavenge_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge_dry_run(Ctx, Input) when ?is_ctx(Ctx) ->
    scavenge_dry_run(Ctx, Input, #{});
scavenge_dry_run(Input, Options) ->
    scavenge_dry_run(ctx:new(), Input, Options).

-spec scavenge_dry_run(ctx:t(), reckon_admin_pb:scavenge_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:scavenge_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
scavenge_dry_run(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/ScavengeDryRun">>, Input, ?DEF(scavenge_request, scavenge_response, <<"reckon.gateway.v1.ScavengeRequest">>), Options).

%% @doc Unary RPC
-spec create_link(reckon_admin_pb:create_link_request()) ->
    {ok, reckon_admin_pb:create_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
create_link(Input) ->
    create_link(ctx:new(), Input, #{}).

-spec create_link(ctx:t() | reckon_admin_pb:create_link_request(), reckon_admin_pb:create_link_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:create_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
create_link(Ctx, Input) when ?is_ctx(Ctx) ->
    create_link(Ctx, Input, #{});
create_link(Input, Options) ->
    create_link(ctx:new(), Input, Options).

-spec create_link(ctx:t(), reckon_admin_pb:create_link_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:create_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
create_link(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/CreateLink">>, Input, ?DEF(create_link_request, create_link_response, <<"reckon.gateway.v1.CreateLinkRequest">>), Options).

%% @doc Unary RPC
-spec delete_link(reckon_admin_pb:delete_link_request()) ->
    {ok, reckon_admin_pb:delete_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_link(Input) ->
    delete_link(ctx:new(), Input, #{}).

-spec delete_link(ctx:t() | reckon_admin_pb:delete_link_request(), reckon_admin_pb:delete_link_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:delete_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_link(Ctx, Input) when ?is_ctx(Ctx) ->
    delete_link(Ctx, Input, #{});
delete_link(Input, Options) ->
    delete_link(ctx:new(), Input, Options).

-spec delete_link(ctx:t(), reckon_admin_pb:delete_link_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:delete_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
delete_link(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/DeleteLink">>, Input, ?DEF(delete_link_request, delete_link_response, <<"reckon.gateway.v1.DeleteLinkRequest">>), Options).

%% @doc Unary RPC
-spec get_link(reckon_admin_pb:get_link_request()) ->
    {ok, reckon_admin_pb:link_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_link(Input) ->
    get_link(ctx:new(), Input, #{}).

-spec get_link(ctx:t() | reckon_admin_pb:get_link_request(), reckon_admin_pb:get_link_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:link_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_link(Ctx, Input) when ?is_ctx(Ctx) ->
    get_link(Ctx, Input, #{});
get_link(Input, Options) ->
    get_link(ctx:new(), Input, Options).

-spec get_link(ctx:t(), reckon_admin_pb:get_link_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:link_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_link(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/GetLink">>, Input, ?DEF(get_link_request, link_info, <<"reckon.gateway.v1.GetLinkRequest">>), Options).

%% @doc Unary RPC
-spec list_links(reckon_admin_pb:list_links_request()) ->
    {ok, reckon_admin_pb:list_links_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_links(Input) ->
    list_links(ctx:new(), Input, #{}).

-spec list_links(ctx:t() | reckon_admin_pb:list_links_request(), reckon_admin_pb:list_links_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:list_links_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_links(Ctx, Input) when ?is_ctx(Ctx) ->
    list_links(Ctx, Input, #{});
list_links(Input, Options) ->
    list_links(ctx:new(), Input, Options).

-spec list_links(ctx:t(), reckon_admin_pb:list_links_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:list_links_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
list_links(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/ListLinks">>, Input, ?DEF(list_links_request, list_links_response, <<"reckon.gateway.v1.ListLinksRequest">>), Options).

%% @doc Unary RPC
-spec start_link(reckon_admin_pb:start_link_request()) ->
    {ok, reckon_admin_pb:start_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
start_link(Input) ->
    start_link(ctx:new(), Input, #{}).

-spec start_link(ctx:t() | reckon_admin_pb:start_link_request(), reckon_admin_pb:start_link_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:start_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
start_link(Ctx, Input) when ?is_ctx(Ctx) ->
    start_link(Ctx, Input, #{});
start_link(Input, Options) ->
    start_link(ctx:new(), Input, Options).

-spec start_link(ctx:t(), reckon_admin_pb:start_link_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:start_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
start_link(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/StartLink">>, Input, ?DEF(start_link_request, start_link_response, <<"reckon.gateway.v1.StartLinkRequest">>), Options).

%% @doc Unary RPC
-spec stop_link(reckon_admin_pb:stop_link_request()) ->
    {ok, reckon_admin_pb:stop_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
stop_link(Input) ->
    stop_link(ctx:new(), Input, #{}).

-spec stop_link(ctx:t() | reckon_admin_pb:stop_link_request(), reckon_admin_pb:stop_link_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:stop_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
stop_link(Ctx, Input) when ?is_ctx(Ctx) ->
    stop_link(Ctx, Input, #{});
stop_link(Input, Options) ->
    stop_link(ctx:new(), Input, Options).

-spec stop_link(ctx:t(), reckon_admin_pb:stop_link_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:stop_link_response(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
stop_link(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/StopLink">>, Input, ?DEF(stop_link_request, stop_link_response, <<"reckon.gateway.v1.StopLinkRequest">>), Options).

%% @doc Unary RPC
-spec get_link_info(reckon_admin_pb:get_link_request()) ->
    {ok, reckon_admin_pb:link_runtime_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_link_info(Input) ->
    get_link_info(ctx:new(), Input, #{}).

-spec get_link_info(ctx:t() | reckon_admin_pb:get_link_request(), reckon_admin_pb:get_link_request() | grpcbox_client:options()) ->
    {ok, reckon_admin_pb:link_runtime_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_link_info(Ctx, Input) when ?is_ctx(Ctx) ->
    get_link_info(Ctx, Input, #{});
get_link_info(Input, Options) ->
    get_link_info(ctx:new(), Input, Options).

-spec get_link_info(ctx:t(), reckon_admin_pb:get_link_request(), grpcbox_client:options()) ->
    {ok, reckon_admin_pb:link_runtime_info(), grpcbox:metadata()} | grpcbox_stream:grpc_error_response() | {error, any()}.
get_link_info(Ctx, Input, Options) ->
    grpcbox_client:unary(Ctx, <<"/reckon.gateway.v1.AdminService/GetLinkInfo">>, Input, ?DEF(get_link_request, link_runtime_info, <<"reckon.gateway.v1.GetLinkRequest">>), Options).

