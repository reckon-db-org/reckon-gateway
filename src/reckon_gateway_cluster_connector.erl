%%% @doc One gen_server per configured cluster. Sub-task 2 of the
%%% catalogue refactor lands the lifecycle skeleton (start, log,
%%% idle); sub-task 3 fills in the actual dist work (set_cookie,
%%% net_adm:ping, member discovery, periodic refresh).
%%%
%%% Registered name: `reckon_gateway_cluster_<id>`.
%%%
%%% Cookie is held in process state; never logged or returned. When
%%% a future API call ever surfaces this state, redact the cookie
%%% field first.
-module(reckon_gateway_cluster_connector).
-behaviour(gen_server).

-export([start_link/1, child_spec/1, name/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2]).

-record(state, {
    cluster_id   :: atom(),
    seed         :: atom(),
    cookie       :: binary(),       %% never log this value
    status       :: not_yet_connected | up | unreachable
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link(reckon_gateway_config:cluster_spec()) ->
    {ok, pid()} | {error, term()}.
start_link(#{cluster_id := Id} = Spec) ->
    gen_server:start_link({local, name(Id)}, ?MODULE, Spec, []).

-spec child_spec(reckon_gateway_config:cluster_spec()) ->
    supervisor:child_spec().
child_spec(#{cluster_id := Id} = Spec) ->
    #{id       => {connector, Id},
      start    => {?MODULE, start_link, [Spec]},
      restart  => permanent,
      shutdown => 5000,
      type     => worker,
      modules  => [?MODULE]}.

-spec name(atom()) -> atom().
name(Id) when is_atom(Id) ->
    list_to_atom("reckon_gateway_cluster_" ++ atom_to_list(Id)).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init(#{cluster_id := Id, seed := Seed, cookie := Cookie}) ->
    logger:info("[reckon_gateway_cluster ~p] init seed=~p cookie=<~b bytes>",
                [Id, Seed, byte_size(Cookie)]),
    %% Sub-task 3 will: set_cookie/ping/member-discover/start refresh
    %% timer here. Today the connector idles.
    {ok, #state{cluster_id = Id,
                seed       = Seed,
                cookie     = Cookie,
                status     = not_yet_connected}}.

handle_call(get_status, _From, #state{cluster_id = Id,
                                       seed = Seed,
                                       status = Status} = State) ->
    %% Cookie deliberately omitted from the reply.
    {reply, #{cluster_id => Id, seed => Seed, status => Status}, State};
handle_call(_Msg, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast(_Msg, State) -> {noreply, State}.

handle_info(_Msg, State) -> {noreply, State}.

terminate(Reason, #state{cluster_id = Id}) ->
    logger:info("[reckon_gateway_cluster ~p] terminating: ~p", [Id, Reason]),
    ok.
