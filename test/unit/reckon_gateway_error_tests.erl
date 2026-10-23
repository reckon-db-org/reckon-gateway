%% A refused stream id reaches the client as InvalidArgument carrying the
%% rule; every other reason stays off the wire (reckon-gater#5).
-module(reckon_gateway_error_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BAD, <<"post-1d17cea1aa1a700d3bcaf8e402ec42920a98e146">>).

rule() ->
    reckon_gater_stream_id:explain(malformed_user_id).

four_tuple_carries_its_rule_as_the_message_test() ->
    R = {invalid_stream_id, malformed_user_id, ?BAD, rule()},
    ?assertEqual({error, <<"3">>, rule()},
                 reckon_gateway_error:wrap(append_events, <<"3">>, R)).

three_tuple_from_an_older_store_gets_the_rule_too_test() ->
    R = {invalid_stream_id, malformed_user_id, ?BAD},
    ?assertEqual({error, <<"3">>, rule()},
                 reckon_gateway_error:wrap(append_events, <<"3">>, R)).

a_refused_id_is_invalid_argument_on_every_operation_test() ->
    R = {invalid_stream_id, malformed_user_id, ?BAD, rule()},
    ?assertEqual({error, <<"3">>, rule()},
                 reckon_gateway_error:wrap(delete_stream, <<"13">>, R)),
    ?assertEqual({error, <<"3">>, rule()},
                 reckon_gateway_error:wrap(get_stream_version, <<"5">>, R)).

other_reasons_send_no_message_test() ->
    ?assertEqual({error, <<"13">>},
                 reckon_gateway_error:wrap(list_streams, <<"13">>,
                                           {rpc_failed, 'n@h', timeout})).

the_rule_names_the_shape_and_the_guide_test() ->
    Rule = rule(),
    ?assertNotEqual(nomatch, binary:match(Rule, <<"<prefix>-<32 hex>">>)),
    ?assertNotEqual(nomatch, binary:match(Rule, <<"stream_ids.html">>)).
