%% @doc gRPC AdminService implementation.
-module(reckon_gateway_admin_service).

-export([
    %% Store Inspection
    get_store_stats/2,
    get_stream_info/2,
    get_event_type_summary/2,
    %% Scavenging
    scavenge/2,
    scavenge_matching/2,
    scavenge_dry_run/2,
    %% Stream Links
    create_link/2,
    delete_link/2,
    get_link/2,
    list_links/2,
    start_link/2,
    stop_link/2,
    get_link_info/2
]).

%%====================================================================
%% Store Inspection
%%====================================================================

get_store_stats(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:store_stats(StoreId) of
                {ok, Stats} ->
                    {ok, #{total_streams => maps:get(total_streams, Stats, 0),
                           total_events => maps:get(total_events, Stats, 0),
                           total_subscriptions => maps:get(total_subscriptions, Stats, 0),
                           total_snapshots => maps:get(total_snapshots, Stats, 0),
                           details => maps_to_strings(Stats)}, Md};
                {error, _Reason} ->
                    {error, <<"13">>}
            end
    end.

get_stream_info(#{store_id := StoreIdBin, stream_id := StreamId}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:stream_info(StoreId, StreamId) of
                {ok, Info} ->
                    {ok, #{stream_id => StreamId,
                           version => maps:get(version, Info, 0),
                           event_count => maps:get(event_count, Info, 0),
                           created_at => maps:get(created_at, Info, 0),
                           last_event_at => maps:get(last_event_at, Info, 0),
                           event_types => maps:get(event_types, Info, [])}, Md};
                {error, _Reason} ->
                    {error, <<"5">>}
            end
    end.

get_event_type_summary(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:event_type_summary(StoreId) of
                {ok, Summary} ->
                    Entries = [#{event_type => maps:get(event_type, S, <<>>),
                                 count => maps:get(count, S, 0)}
                               || S <- Summary],
                    {ok, #{entries => Entries}, Md};
                {error, _Reason} ->
                    {error, <<"13">>}
            end
    end.

%%====================================================================
%% Scavenging
%%====================================================================

scavenge(#{store_id := StoreIdBin, stream_id := StreamId, options := Opts}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:scavenge(StoreId, StreamId, Opts) of
                {ok, Result} ->
                    {ok, scavenge_result_to_proto(Result), Md};
                {error, Reason} ->
                    scavenge_error(Reason)
            end
    end.

scavenge_matching(#{store_id := StoreIdBin, pattern := Pattern, options := Opts}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:scavenge_matching(StoreId, Pattern, Opts) of
                {ok, Results} ->
                    ProtoResults = [scavenge_result_to_proto(R) || R <- Results],
                    {ok, #{results => ProtoResults}, Md};
                {error, Reason} ->
                    scavenge_error(Reason)
            end
    end.

scavenge_dry_run(#{store_id := StoreIdBin, stream_id := StreamId, options := Opts}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:scavenge_dry_run(StoreId, StreamId, Opts) of
                {ok, Result} ->
                    {ok, scavenge_result_to_proto(Result), Md};
                {error, Reason} ->
                    scavenge_error(Reason)
            end
    end.

%% @private Map worker-side errors to the right gRPC status code.
%% Caller-side errors (no_snapshot, stream_not_found, invalid_stream_id)
%% are 3 (InvalidArgument). Anything else stays 13 (Internal).
scavenge_error({no_snapshot, _}) -> {error, <<"3">>};
scavenge_error({stream_not_found, _}) -> {error, <<"3">>};
scavenge_error({invalid_stream_id, _, _}) -> {error, <<"3">>};
scavenge_error(_) -> {error, <<"13">>}.

%%====================================================================
%% Stream Links
%%====================================================================

create_link(#{store_id := StoreIdBin} = Req, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            LinkSpec = #{name => maps:get(name, Req, <<>>),
                         source => maps:get(source, Req, <<>>),
                         target => maps:get(target, Req, <<>>)},
            ok = reckon_gater_api:create_link(StoreId, LinkSpec),
            {ok, #{}, Md}
    end.

delete_link(#{store_id := StoreIdBin, name := Name}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            ok = reckon_gater_api:delete_link(StoreId, Name),
            {ok, #{}, Md}
    end.

get_link(#{store_id := StoreIdBin, name := Name}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:get_link(StoreId, Name) of
                {ok, Link} ->
                    {ok, link_to_proto(Link), Md};
                {error, _Reason} ->
                    {error, <<"5">>}
            end
    end.

list_links(#{store_id := StoreIdBin}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:list_links(StoreId) of
                {ok, Links} ->
                    {ok, #{links => [link_to_proto(L) || L <- Links]}, Md};
                {error, _Reason} ->
                    {error, <<"13">>}
            end
    end.

start_link(#{store_id := StoreIdBin, name := Name}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            ok = reckon_gater_api:start_link(StoreId, Name),
            {ok, #{}, Md}
    end.

stop_link(#{store_id := StoreIdBin, name := Name}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            ok = reckon_gater_api:stop_link(StoreId, Name),
            {ok, #{}, Md}
    end.

get_link_info(#{store_id := StoreIdBin, name := Name}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            {error, <<"3">>};
        {ok, StoreId} ->
            case reckon_gater_api:link_info(StoreId, Name) of
                {ok, Info} ->
                    {ok, #{name => Name,
                           status => maps:get(status, Info, <<"unknown">>),
                           events_processed => maps:get(events_processed, Info, 0),
                           details => maps_to_strings(Info)}, Md};
                {error, _Reason} ->
                    {error, <<"5">>}
            end
    end.

%%====================================================================
%% Internal
%%====================================================================

scavenge_result_to_proto(Result) ->
    #{events_removed => maps:get(events_removed, Result, 0),
      events_remaining => maps:get(events_remaining, Result, 0),
      space_reclaimed_bytes => maps:get(space_reclaimed_bytes, Result, 0),
      details => maps_to_strings(Result)}.

link_to_proto(Link) ->
    #{name => maps:get(name, Link, <<>>),
      source => maps:get(source, Link, <<>>),
      target => maps:get(target, Link, <<>>),
      options => maps_to_strings(maps:get(options, Link, #{}))}.

maps_to_strings(Map) when is_map(Map) ->
    maps:fold(
        fun(K, V, Acc) ->
            Key = iolist_to_binary(io_lib:format("~p", [K])),
            Val = iolist_to_binary(io_lib:format("~p", [V])),
            Acc#{Key => Val}
        end, #{}, Map);
maps_to_strings(_) -> #{}.
