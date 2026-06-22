%%% @doc Shared helpers for the HTTP/JSON API handlers.
%%%
%%% Converts between the internal #event{} / gater-map types and JSON,
%%% encodes/decodes request/response bodies, and provides uniform
%%% error response helpers.
%%%
%%% JSON filter shape (mirrors proto TagFilter OneOf):
%%%   {"match_any": ["tag1", "tag2"]}
%%%   {"match_all": ["tag1", "tag2"]}
%%%   {"event_type": "seat_reserved_v1"}
%%%   {"and": [{...}, {...}]}
%%%   {"or": [{...}, {...}]}
-module(reckon_gateway_http).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-export([
    %% Request
    read_json_body/1,
    qs_int/3,
    qs_binary/3,
    qs_list/3,
    parse_expected_version/1,

    %% Response
    reply_json/3,
    reply_error/3,
    cors_preflight/1,
    cors_headers/0,

    %% Conversion
    event_to_json_map/1,
    proposed_from_json/1,
    decode_filter/1,
    dispatch_error/2
]).

%%====================================================================
%% Request helpers
%%====================================================================

read_json_body(Req0) ->
    case cowboy_req:has_body(Req0) of
        false ->
            {ok, #{}, Req0};
        true ->
            {ok, Body, Req} = cowboy_req:read_body(Req0),
            case Body of
                <<>> -> {ok, #{}, Req};
                _    ->
                    try {ok, json:decode(Body), Req}
                    catch _:_ -> {error, invalid_json}
                    end
            end
    end.

qs_int(Req, Key, Default) ->
    case cowboy_req:match_qs([{Key, [], undefined}], Req) of
        #{Key := undefined} -> Default;
        #{Key := V} when is_binary(V) ->
            try binary_to_integer(V) catch _:_ -> Default end;
        #{Key := V} when is_integer(V) -> V;
        _ -> Default
    end.

qs_binary(Req, Key, Default) ->
    case cowboy_req:match_qs([{Key, [], undefined}], Req) of
        #{Key := undefined} -> Default;
        #{Key := V}         -> V;
        _                   -> Default
    end.

%% Comma-separated list query param: "a,b,c" → [<<"a">>, <<"b">>, <<"c">>]
qs_list(Req, Key, Default) ->
    case qs_binary(Req, Key, undefined) of
        undefined -> Default;
        <<>>      -> Default;
        Bin       -> [string:trim(T) || T <- binary:split(Bin, <<",">>, [global])]
    end.

%% -2 | "any" → -2 (AnyVersion)
%% -1 | "no_stream" → -1 (NoStream)
%% -4 | "exists" → -4 (StreamExists)
%% N (integer) → N (exact version)
parse_expected_version(V) when is_integer(V) -> V;
parse_expected_version(<<"any">>)             -> -2;
parse_expected_version(<<"no_stream">>)       -> -1;
parse_expected_version(<<"exists">>)          -> -4;
parse_expected_version(V) when is_binary(V)  ->
    try binary_to_integer(V) catch _:_ -> -2 end;
parse_expected_version(_)                     -> -2.

%%====================================================================
%% Response helpers
%%====================================================================

cors_headers() ->
    #{
        <<"access-control-allow-origin">>  => <<"*">>,
        <<"access-control-allow-methods">> => <<"GET, POST, DELETE, OPTIONS">>,
        <<"access-control-allow-headers">> => <<"content-type, authorization">>
    }.

reply_json(Status, Body, Req) ->
    cowboy_req:reply(Status,
        maps:merge(cors_headers(), #{<<"content-type">> => <<"application/json">>}),
        json:encode(Body),
        Req).

reply_error(Status, Reason, Req) when is_atom(Reason) ->
    reply_error(Status, atom_to_binary(Reason, utf8), Req);
reply_error(Status, Reason, Req) when is_binary(Reason) ->
    reply_json(Status, #{<<"error">> => Reason}, Req);
reply_error(Status, Reason, Req) ->
    Msg = iolist_to_binary(io_lib:format("~p", [Reason])),
    reply_json(Status, #{<<"error">> => Msg}, Req).

cors_preflight(Req) ->
    cowboy_req:reply(204, cors_headers(), <<>>, Req).

%%====================================================================
%% Conversion
%%====================================================================

event_to_json_map(#event{} = E) ->
    #{
        <<"event_id">>                => E#event.event_id,
        <<"event_type">>              => E#event.event_type,
        <<"stream_id">>               => E#event.stream_id,
        <<"version">>                 => E#event.version,
        <<"data">>                    => data_for_json(E#event.data, E#event.data_content_type),
        <<"metadata">>                => data_for_json(E#event.metadata, E#event.metadata_content_type),
        <<"tags">>                    => case E#event.tags of undefined -> []; T -> T end,
        <<"timestamp">>               => E#event.timestamp,
        <<"epoch_us">>                => E#event.epoch_us,
        <<"data_content_type">>       => E#event.data_content_type,
        <<"metadata_content_type">>   => E#event.metadata_content_type,
        <<"prev_event_hash">>         => hash_b64(E#event.prev_event_hash)
    }.

%% Build an internal event map from a decoded JSON map.
%% Mirrors the logic in reckon_gateway_convert:proposed_to_event/2 but
%% accepts already-decoded data (maps) rather than encoded bytes.
proposed_from_json(#{<<"event_type">> := EventType} = Map) ->
    EventId = case maps:get(<<"event_id">>, Map, <<>>) of
        <<>> -> reckon_gater_uuid:to_string(reckon_gater_uuid:v7());
        Id   -> Id
    end,
    Tags = case maps:get(<<"tags">>, Map, []) of
        []   -> undefined;
        Ts   -> Ts
    end,
    #{
        event_id                => EventId,
        event_type              => EventType,
        data                    => maps:get(<<"data">>, Map, #{}),
        metadata                => maps:get(<<"metadata">>, Map, #{}),
        tags                    => Tags,
        data_content_type       => maps:get(<<"data_content_type">>, Map, ?CONTENT_TYPE_JSON),
        metadata_content_type   => maps:get(<<"metadata_content_type">>, Map, ?CONTENT_TYPE_JSON)
    };
proposed_from_json(_) ->
    {error, missing_event_type}.

%% Decode a JSON TagFilter map to the Erlang filter term expected by
%% reckon_gater_api / reckon_gateway_dcb_service.
-spec decode_filter(map()) -> {ok, term()} | {error, term()}.
decode_filter(#{<<"match_any">> := Tags}) when is_list(Tags) ->
    {ok, {any_of, Tags}};
decode_filter(#{<<"match_all">> := Tags}) when is_list(Tags) ->
    {ok, {all_of, Tags}};
decode_filter(#{<<"event_type">> := T}) when is_binary(T), T =/= <<>> ->
    {ok, {event_type, T}};
decode_filter(#{<<"and">> := Filters}) when is_list(Filters) ->
    decode_subfilters(Filters, and_, []);
decode_filter(#{<<"or">> := Filters}) when is_list(Filters) ->
    decode_subfilters(Filters, or_, []);
decode_filter(_) ->
    {error, malformed_tag_filter}.

%% Map dispatch error atoms to HTTP status codes.
dispatch_error(store_unknown, Req)        -> reply_error(404, store_unknown, Req);
dispatch_error(invalid_store_id, Req)     -> reply_error(400, invalid_store_id, Req);
dispatch_error(cluster_unavailable, Req)  -> reply_error(503, cluster_unavailable, Req);
dispatch_error(not_supported, Req)        -> reply_error(501, not_supported, Req);
dispatch_error(no_events, Req)            -> reply_error(400, no_events, Req);
dispatch_error(malformed_tag_filter, Req) -> reply_error(400, malformed_tag_filter, Req);
dispatch_error(version_conflict, Req)     -> reply_error(409, version_conflict, Req);
dispatch_error({version_conflict, _}, Req)-> reply_error(409, version_conflict, Req);
dispatch_error({rpc_failed, _, _}, Req)   -> reply_error(502, rpc_failed, Req);
dispatch_error(Reason, Req)               -> reply_error(500, Reason, Req).

%%====================================================================
%% Internal
%%====================================================================

decode_subfilters([], OpAtom, Acc) ->
    {ok, {OpAtom, lists:reverse(Acc)}};
decode_subfilters([Sub | Rest], OpAtom, Acc) ->
    case decode_filter(Sub) of
        {ok, Decoded}    -> decode_subfilters(Rest, OpAtom, [Decoded | Acc]);
        {error, _} = Err -> Err
    end.

data_for_json(Data, _CT) when is_map(Data)              -> Data;
data_for_json(undefined, _CT)                           -> null;
data_for_json(<<>>, _CT)                                -> null;
data_for_json(Bytes, ?CONTENT_TYPE_JSON) when is_binary(Bytes) ->
    try json:decode(Bytes) catch _:_ -> base64:encode(Bytes) end;
data_for_json(Bytes, _CT) when is_binary(Bytes)         -> base64:encode(Bytes).

hash_b64(undefined)                    -> <<"">>;
hash_b64(<<>>)                         -> <<"">>;
hash_b64(Hash) when is_binary(Hash)    -> base64:encode(Hash).
