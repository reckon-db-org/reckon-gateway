%% @doc gRPC CausationService implementation.
-module(reckon_gateway_causation_service).

-export([
    get_effects/2,
    get_cause/2,
    get_causation_chain/2,
    get_correlated/2,
    build_causation_graph/2
]).

get_effects(#{store_id := StoreIdBin, event_id := EventId}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_effects(StoreId, EventId) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

get_cause(#{store_id := StoreIdBin, event_id := EventId}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_cause(StoreId, EventId) of
        {ok, Event} ->
            {ok, #{event => reckon_gateway_convert:event_to_recorded(Event)}, Md};
        {error, _Reason} ->
            {error, <<"5">>}
    end.

get_causation_chain(#{store_id := StoreIdBin, event_id := EventId}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_causation_chain(StoreId, EventId) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

get_correlated(#{store_id := StoreIdBin, correlation_id := CorrelationId}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:get_correlated(StoreId, CorrelationId) of
        {ok, Events} ->
            Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
            {ok, #{events => Recorded}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
    end.

build_causation_graph(#{store_id := StoreIdBin, event_id := EventId}, Md) ->
    StoreId = reckon_gateway_convert:store_id(StoreIdBin),
    case esdb_gater_api:build_causation_graph(StoreId, EventId) of
        {ok, Graph} ->
            {ok, #{root => graph_to_proto(Graph)}, Md};
        {error, _Reason} ->
            {error, <<"13">>}
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
