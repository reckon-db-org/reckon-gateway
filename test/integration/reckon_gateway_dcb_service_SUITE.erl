%%% @doc Integration suite for reckon_gateway_dcb_service.
%%%
%%% Exercises the handler's full request/response path with
%%% reckon_gateway_dispatch mecked: the handler receives a proto map,
%%% decodes the TagFilter, calls dispatch, and renders the result
%%% back into the wire-shape response (Committed | Conflict | gRPC
%%% error). Unit tests already cover the pure filter algebra; this
%%% suite covers the glue + the error-translation table.
%%%
%%% reckon_gateway_dispatch is stubbed end-to-end. A real-cluster
%%% suite using a live reckon_db store is a separate piece of work
%%% (deferred until reckon-db's CT harness lands a reusable
%%% test-cluster fixture).
-module(reckon_gateway_dcb_service_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([
    all/0,
    init_per_suite/1,
    end_per_suite/1,
    init_per_testcase/2,
    end_per_testcase/2
]).

-export([
    happy_path_commit/1,
    conflict_returns_max_seq/1,
    invalid_store_id_returns_invalid_argument/1,
    malformed_tag_filter_returns_invalid_argument/1,
    no_events_returns_invalid_argument/1,
    pre_dcb_backing_returns_unimplemented/1,
    store_unknown_returns_not_found/1,
    cluster_unavailable_returns_unavailable/1,
    rpc_failure_returns_internal/1,
    compound_filter_decoded_and_dispatched/1,
    read_dcb_context_happy_path/1,
    read_dcb_context_empty_when_no_tags/1,
    read_dcb_context_filters_to_dcb_stream/1,
    read_dcb_context_returns_minus_one_when_empty/1,
    read_dcb_context_compound_filter_refines_client_side/1,
    read_then_append_loop/1
]).

-define(STORE_ID,     <<"test_store">>).
-define(STORE_ATOM,   test_store).
-define(DCB_STREAM,   <<"_dcb">>).
-define(METADATA,     #{}).

%%====================================================================
%% Common Test boilerplate
%%====================================================================

all() ->
    [
        happy_path_commit,
        conflict_returns_max_seq,
        invalid_store_id_returns_invalid_argument,
        malformed_tag_filter_returns_invalid_argument,
        no_events_returns_invalid_argument,
        pre_dcb_backing_returns_unimplemented,
        store_unknown_returns_not_found,
        cluster_unavailable_returns_unavailable,
        rpc_failure_returns_internal,
        compound_filter_decoded_and_dispatched,
        read_dcb_context_happy_path,
        read_dcb_context_empty_when_no_tags,
        read_dcb_context_filters_to_dcb_stream,
        read_dcb_context_returns_minus_one_when_empty,
        read_dcb_context_compound_filter_refines_client_side,
        read_then_append_loop
    ].

init_per_suite(Config) ->
    application:ensure_all_started(meck),
    Config.

end_per_suite(_Config) ->
    ok.

init_per_testcase(_TC, Config) ->
    meck:new(reckon_gateway_dispatch, [passthrough]),
    Config.

end_per_testcase(_TC, _Config) ->
    catch meck:unload(reckon_gateway_dispatch),
    ok.

%%====================================================================
%% AppendIfNoTagMatches
%%====================================================================

%% Happy path: a flat any_of filter, server reports a commit at seq 42.
happy_path_commit(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(append_if_no_tag_matches,
            [Store, Filter, Cutoff, Events]) ->
                ?STORE_ATOM = Store,
                {any_of, [<<"slot:7">>]} = Filter,
                -1 = Cutoff,
                [_OneEvent] = Events,
                {ok, 42}
        end),
    Req = #{
        store_id   => ?STORE_ID,
        tag_filter => #{kind => {match_any, #{tags => [<<"slot:7">>]}}},
        seq_cutoff => -1,
        events     => [proposed_event(<<"reserved_v1">>, [<<"slot:7">>])]
    },
    {ok, Response, ?METADATA} = call_append(Req),
    ?assertEqual({committed, #{last_seq => 42}},
                 maps:get(result, Response)),
    ?assertEqual(1, meck:num_calls(reckon_gateway_dispatch,
                                    call, '_')).

%% Conflict: dispatch returns {context_changed, MaxSeq}; handler maps
%% to the Conflict oneof variant, NOT a gRPC error.
conflict_returns_max_seq(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(append_if_no_tag_matches, _Args) ->
                {error, {context_changed, 99}}
        end),
    Req = append_req(<<"slot:1">>, -1, [proposed_event(<<"x_v1">>, [<<"slot:1">>])]),
    {ok, Response, ?METADATA} = call_append(Req),
    ?assertEqual({conflict, #{max_seq => 99}},
                 maps:get(result, Response)).

%% Malformed store_id (binary that fails the regex) -> INVALID_ARGUMENT.
invalid_store_id_returns_invalid_argument(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(_, _) -> ct:fail(dispatch_should_not_be_called) end),
    Req = (append_req(<<"slot:1">>, -1, []))#{
        store_id => <<"not valid! has spaces">>
    },
    ?assertEqual({error, <<"3">>}, call_append(Req)),
    ?assertEqual(0, meck:num_calls(reckon_gateway_dispatch, call, '_')).

%% TagFilter map missing required keys -> INVALID_ARGUMENT.
malformed_tag_filter_returns_invalid_argument(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(_, _) -> ct:fail(dispatch_should_not_be_called) end),
    Req = #{
        store_id   => ?STORE_ID,
        tag_filter => #{},   %% no `kind`
        seq_cutoff => -1,
        events     => []
    },
    ?assertEqual({error, <<"3">>}, call_append(Req)).

%% Dispatch returns {error, no_events} -> INVALID_ARGUMENT.
no_events_returns_invalid_argument(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(_, _) -> {error, no_events} end),
    Req = append_req(<<"t">>, -1, []),
    ?assertEqual({error, <<"3">>}, call_append(Req)).

%% Backing reckon-db pre-DCB returns {error, not_supported} ->
%% gRPC UNIMPLEMENTED (12).
pre_dcb_backing_returns_unimplemented(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(_, _) -> {error, not_supported} end),
    Req = append_req(<<"t">>, -1, [proposed_event(<<"x_v1">>, [<<"t">>])]),
    ?assertEqual({error, <<"12">>}, call_append(Req)).

%% Catalogue has no entry for the store_id -> NOT_FOUND.
store_unknown_returns_not_found(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(_, _) -> {error, store_unknown} end),
    Req = append_req(<<"t">>, -1, [proposed_event(<<"x_v1">>, [<<"t">>])]),
    ?assertEqual({error, <<"5">>}, call_append(Req)).

%% Cluster has no healthy member -> UNAVAILABLE.
cluster_unavailable_returns_unavailable(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(_, _) -> {error, cluster_unavailable} end),
    Req = append_req(<<"t">>, -1, [proposed_event(<<"x_v1">>, [<<"t">>])]),
    ?assertEqual({error, <<"14">>}, call_append(Req)).

%% Unknown dispatch failure -> INTERNAL.
rpc_failure_returns_internal(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(_, _) ->
                {error, {rpc_failed, 'parksim@host', timeout}}
        end),
    Req = append_req(<<"t">>, -1, [proposed_event(<<"x_v1">>, [<<"t">>])]),
    ?assertEqual({error, <<"13">>}, call_append(Req)).

%% Compound filter (or_ of and_ + any_of) decoded correctly and
%% passed through to dispatch.
compound_filter_decoded_and_dispatched(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(append_if_no_tag_matches, [_, Filter, _, _]) ->
                Expected = {or_, [{and_, [{any_of, [<<"r">>]},
                                          {all_of, [<<"g">>]}]},
                                  {any_of, [<<"c">>]}]},
                Expected = Filter,
                {ok, 0}
        end),
    ProtoFilter = #{kind => {disjunction, #{filters => [
        #{kind => {conjunction, #{filters => [
            #{kind => {match_any, #{tags => [<<"r">>]}}},
            #{kind => {match_all, #{tags => [<<"g">>]}}}
        ]}}},
        #{kind => {match_any, #{tags => [<<"c">>]}}}
    ]}}},
    Req = #{
        store_id   => ?STORE_ID,
        tag_filter => ProtoFilter,
        seq_cutoff => -1,
        events     => [proposed_event(<<"x_v1">>, [<<"r">>, <<"g">>])]
    },
    {ok, _Response, _} = call_append(Req).

%%====================================================================
%% ReadDcbContext
%%====================================================================

%% Happy path: dispatch returns three #event{} records (two DCB, one
%% non-DCB), handler filters to DCB-stream-only and computes max_seq.
read_dcb_context_happy_path(_Config) ->
    DcbA = make_event(<<"reserved_v1">>, ?DCB_STREAM, 5,  [<<"slot:1">>]),
    DcbB = make_event(<<"reserved_v1">>, ?DCB_STREAM, 11, [<<"slot:1">>]),
    Other = make_event(<<"audit_v1">>,   <<"audit">>, 99, [<<"slot:1">>]),
    meck:expect(reckon_gateway_dispatch, call,
        fun(read_by_tags, [Store, Tags, Opts]) ->
                ?STORE_ATOM = Store,
                [<<"slot:1">>] = Tags,
                #{match := any, batch_size := 100} = Opts,
                {ok, [DcbA, Other, DcbB]}
        end),
    Req = read_req(<<"slot:1">>, 100),
    {ok, Resp, ?METADATA} = call_read(Req),
    Events = maps:get(events, Resp),
    ?assertEqual(2, length(Events)),
    ?assertEqual(11, maps:get(max_seq, Resp)).

%% Vacuous compound filter ({or_, []}) -> empty result, no dispatch.
read_dcb_context_empty_when_no_tags(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(_, _) -> ct:fail(dispatch_should_not_be_called) end),
    Req = #{
        store_id   => ?STORE_ID,
        tag_filter => #{kind => {disjunction, #{filters => []}}},
        batch_size => 100
    },
    {ok, Resp, ?METADATA} = call_read(Req),
    ?assertEqual([], maps:get(events, Resp)),
    ?assertEqual(-1, maps:get(max_seq, Resp)).

%% Even if dispatch returns events with the right tag from a non-DCB
%% stream, they MUST NOT be included.
read_dcb_context_filters_to_dcb_stream(_Config) ->
    Other1 = make_event(<<"x_v1">>, <<"users">>,  3,  [<<"slot:1">>]),
    Other2 = make_event(<<"y_v1">>, <<"orders">>, 7,  [<<"slot:1">>]),
    meck:expect(reckon_gateway_dispatch, call,
        fun(read_by_tags, _Args) ->
                {ok, [Other1, Other2]}
        end),
    Req = read_req(<<"slot:1">>, 100),
    {ok, Resp, ?METADATA} = call_read(Req),
    ?assertEqual([], maps:get(events, Resp)),
    ?assertEqual(-1, maps:get(max_seq, Resp)).

%% Empty result set after filtering -> max_seq is -1.
read_dcb_context_returns_minus_one_when_empty(_Config) ->
    meck:expect(reckon_gateway_dispatch, call,
        fun(read_by_tags, _Args) -> {ok, []} end),
    Req = read_req(<<"slot:1">>, 100),
    {ok, Resp, ?METADATA} = call_read(Req),
    ?assertEqual(-1, maps:get(max_seq, Resp)).

%% A compound filter pulls a broader tag superset, then client-side
%% refines so only events satisfying the full predicate are returned.
read_dcb_context_compound_filter_refines_client_side(_Config) ->
    %% {and_, [any_of [<<"r">>], all_of [<<"g">>]]}
    %% reader pulls [<<"r">>, <<"g">>] superset, then keeps only
    %% events tagged with BOTH r and g.
    OnlyR = make_event(<<"x_v1">>, ?DCB_STREAM, 1, [<<"r">>]),
    BothRG = make_event(<<"x_v1">>, ?DCB_STREAM, 2, [<<"r">>, <<"g">>]),
    OnlyG = make_event(<<"x_v1">>, ?DCB_STREAM, 3, [<<"g">>]),
    meck:expect(reckon_gateway_dispatch, call,
        fun(read_by_tags, [_Store, Tags, _Opts]) ->
                ?assertEqual([<<"g">>, <<"r">>], lists:sort(Tags)),
                {ok, [OnlyR, BothRG, OnlyG]}
        end),
    ProtoFilter = #{kind => {conjunction, #{filters => [
        #{kind => {match_any, #{tags => [<<"r">>]}}},
        #{kind => {match_all, #{tags => [<<"g">>]}}}
    ]}}},
    Req = #{
        store_id   => ?STORE_ID,
        tag_filter => ProtoFilter,
        batch_size => 100
    },
    {ok, Resp, ?METADATA} = call_read(Req),
    Events = maps:get(events, Resp),
    ?assertEqual(1, length(Events)),
    ?assertEqual(2, maps:get(max_seq, Resp)).

%%====================================================================
%% End-to-end Decision loop
%%====================================================================

%% Canonical pattern: read context, observe cutoff, attempt append,
%% retry with refreshed context after a conflict, finally commit.
read_then_append_loop(_Config) ->
    DcbAt5 = make_event(<<"reserved_v1">>, ?DCB_STREAM, 5, [<<"slot:42">>]),

    %% Step 1: read context.
    meck:expect(reckon_gateway_dispatch, call,
        fun(read_by_tags, _Args) -> {ok, [DcbAt5]} end),
    ReadReq = read_req(<<"slot:42">>, 100),
    {ok, ReadResp, _} = call_read(ReadReq),
    ?assertEqual(5, maps:get(max_seq, ReadResp)),

    %% Step 2: attempt append with cutoff=5 — server has moved on.
    meck:expect(reckon_gateway_dispatch, call,
        fun(append_if_no_tag_matches, [_, _, 5, _]) ->
                {error, {context_changed, 7}}
        end),
    Append1 = append_req(<<"slot:42">>, 5,
                         [proposed_event(<<"reserved_v1">>, [<<"slot:42">>])]),
    {ok, Resp1, _} = call_append(Append1),
    ?assertEqual({conflict, #{max_seq => 7}},
                 maps:get(result, Resp1)),

    %% Step 3: re-read, find new cutoff at 7, attempt append again.
    meck:expect(reckon_gateway_dispatch, call,
        fun(append_if_no_tag_matches, [_, _, 7, _]) ->
                {ok, 8}
        end),
    Append2 = append_req(<<"slot:42">>, 7,
                         [proposed_event(<<"reserved_v1">>, [<<"slot:42">>])]),
    {ok, Resp2, _} = call_append(Append2),
    ?assertEqual({committed, #{last_seq => 8}},
                 maps:get(result, Resp2)).

%%====================================================================
%% Helpers
%%====================================================================

call_append(Req) ->
    reckon_gateway_dcb_service:append_if_no_tag_matches(Req, ?METADATA).

call_read(Req) ->
    reckon_gateway_dcb_service:read_dcb_context(Req, ?METADATA).

append_req(Tag, Cutoff, Events) ->
    #{
        store_id   => ?STORE_ID,
        tag_filter => #{kind => {match_any, #{tags => [Tag]}}},
        seq_cutoff => Cutoff,
        events     => Events
    }.

read_req(Tag, BatchSize) ->
    #{
        store_id   => ?STORE_ID,
        tag_filter => #{kind => {match_any, #{tags => [Tag]}}},
        batch_size => BatchSize
    }.

proposed_event(Type, Tags) ->
    #{
        event_id              => <<>>,
        event_type            => Type,
        data                  => <<"{}">>,
        metadata              => <<"{}">>,
        tags                  => Tags,
        data_content_type     => <<"application/json">>,
        metadata_content_type => <<"application/json">>
    }.

make_event(Type, StreamId, Version, Tags) ->
    #event{
        event_id   = iolist_to_binary(io_lib:format("ev-~p", [Version])),
        event_type = Type,
        stream_id  = StreamId,
        version    = Version,
        data       = #{},
        metadata   = #{},
        tags       = Tags
    }.
