%% @doc gRPC CausationService implementation.
-module(reckon_gateway_causation_service).
-behaviour(reckon_gateway_v_1_causation_service_bhvr).

-export([
    get_effects/2,
    get_cause/2,
    get_causation_chain/2,
    get_correlated/2,
    build_causation_graph/2
]).

get_effects(Ctx, #{store_id := StoreIdBin, event_id := EventId}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_effects(StoreId, EventId) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

get_cause(Ctx, #{store_id := StoreIdBin, event_id := EventId}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_cause(StoreId, EventId) of
        {ok, Event} ->
            {ok, #{event => reckon_gateway_convert:event_to_recorded(Event)}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"5">>, format_error(Reason)}}
    end.

get_causation_chain(Ctx, #{store_id := StoreIdBin, event_id := EventId}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_causation_chain(StoreId, EventId) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

get_correlated(Ctx, #{store_id := StoreIdBin, correlation_id := CorrelationId}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_correlated(StoreId, CorrelationId) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

build_causation_graph(Ctx, #{store_id := StoreIdBin, event_id := EventId}) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:build_causation_graph(StoreId, EventId) of
        {ok, Graph} ->
            {ok, #{root => graph_to_proto(Graph)}, Ctx};
        {error, Reason} ->
            {grpc_error, {<<"13">>, format_error(Reason)}}
    end.

%%====================================================================
%% Internal
%%====================================================================

graph_to_proto(#{event := Event, children := Children}) ->
    #{event => reckon_gateway_convert:event_to_recorded(Event),
      children => [graph_to_proto(C) || C <- Children]};
graph_to_proto(#{event := Event}) ->
    #{event => reckon_gateway_convert:event_to_recorded(Event),
      children => []};
graph_to_proto(_) ->
    #{event => #{}, children => []}.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
