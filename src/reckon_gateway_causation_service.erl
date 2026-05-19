%% @doc gRPC CausationService implementation.
%%
%% Error paths routed through reckon_gateway_error so the
%% underlying reason is logged server-side (grpc-erl drops
%% grpc-message on unary; see reckon_gateway_error docstring).
-module(reckon_gateway_causation_service).

-export([
    get_effects/2,
    get_cause/2,
    get_causation_chain/2,
    get_correlated/2,
    build_causation_graph/2
]).

get_effects(#{store_id := StoreIdBin, event_id := EventId}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(get_effects, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(get_effects, [StoreId, EventId]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(get_effects, <<"13">>, Reason)
            end
    end.

get_cause(#{store_id := StoreIdBin, event_id := EventId}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(get_cause, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(get_cause, [StoreId, EventId]) of
                {ok, Event} ->
                    {ok, #{event => reckon_gateway_convert:event_to_recorded(Event)}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(get_cause, <<"5">>, Reason)
            end
    end.

get_causation_chain(#{store_id := StoreIdBin, event_id := EventId}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(get_causation_chain, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(get_causation_chain, [StoreId, EventId]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(get_causation_chain, <<"13">>, Reason)
            end
    end.

get_correlated(#{store_id := StoreIdBin, correlation_id := CorrelationId}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(get_correlated, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(get_correlated, [StoreId, CorrelationId]) of
                {ok, Events} ->
                    Recorded = [reckon_gateway_convert:event_to_recorded(E) || E <- Events],
                    {ok, #{events => Recorded}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(get_correlated, <<"13">>, Reason)
            end
    end.

build_causation_graph(#{store_id := StoreIdBin, event_id := EventId}, Md) ->
    case reckon_gateway_convert:try_store_id(StoreIdBin) of
        {error, invalid_store_id} ->
            reckon_gateway_error:wrap(build_causation_graph, <<"3">>, invalid_store_id);
        {ok, StoreId} ->
            case reckon_gateway_dispatch:call(build_causation_graph, [StoreId, EventId]) of
                {ok, Graph} ->
                    {ok, #{root => graph_to_proto(Graph)}, Md};
                {error, Reason} ->
                    reckon_gateway_error:wrap(build_causation_graph, <<"13">>, Reason)
            end
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
