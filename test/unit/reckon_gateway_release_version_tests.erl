%%% @doc The release version a box reports is the version it was released as
%%% (reckon-gateway#2).
%%%
%%% rebar.config names the relx release with a literal version, and a literal
%%% is what allowed the drift: it said 0.27.0 while the app and every git tag
%%% said 0.30.1, so six releases booted as releases/0.27.0/ and an operator
%%% reading the running version read the wrong answer.
%%%
%%% The version stays a literal on purpose. The release guard
%%% (macula-ci-images#6) reads rebar.config as TEXT and compares this tuple to
%%% the tag and to every app's {vsn}; a version supplied by an atom or by
%%% rebar.config.script is one the guard cannot read and it refuses the tag
%%% rather than skipping the check. So the drift is caught here instead: a
%%% release whose version is not the app's version fails this suite, which
%%% runs before anything is tagged.
-module(reckon_gateway_release_version_tests).

-include_lib("eunit/include/eunit.hrl").

%% Every relx release tuple in rebar.config, in both the top level and every
%% profile, because a release can be assembled from either.
every_release_names_the_app_version_test() ->
    Versions = lists:usort(releases(consult("rebar.config"))),
    ?assertNotEqual([], Versions),
    ?assertEqual([app_vsn()], Versions).

%% The release the repo actually assembles: the prod profile's, which is what
%% the image build runs (`rebar3 as prod release` in the Dockerfile). Named
%% separately so a future profile cannot satisfy the test above while the
%% shipped one drifts.
the_prod_release_names_the_app_version_test() ->
    Prod = [Settings || {prod, Settings} <- profiles(consult("rebar.config"))],
    ?assertNotEqual([], Prod),
    ?assertEqual([app_vsn()], lists:usort(releases(lists:append(Prod)))).

app_vsn() ->
    [{application, reckon_gateway, Props}] = consult("src/reckon_gateway.app.src"),
    proplists:get_value(vsn, Props).

releases(Config) ->
    lists:flatmap(fun releases_in/1, Config).

releases_in({relx, Props}) ->
    [Vsn || {release, {reckon_gateway, Vsn}, _Apps} <- Props];
releases_in({profiles, Profiles}) ->
    lists:flatmap(fun({_Name, Settings}) -> releases(Settings) end, Profiles);
releases_in(_Other) ->
    [].

profiles(Config) ->
    lists:append([P || {profiles, P} <- Config]).

consult(Relative) ->
    {ok, Terms} = file:consult(alongside(Relative)),
    Terms.

%% Relative to the beam rather than the working directory, because eunit runs
%% from wherever the developer happens to be standing.
alongside(Name) -> climb(filename:dirname(code:which(?MODULE)), Name, 8).

climb(_Dir, Name, 0) -> Name;
climb(Dir, Name, Left) ->
    Candidate = filename:join(Dir, Name),
    found(filelib:is_regular(Candidate), Candidate, Dir, Name, Left).

found(true, Candidate, _Dir, _Name, _Left) -> Candidate;
found(false, _Candidate, Dir, Name, Left) ->
    climb(filename:dirname(Dir), Name, Left - 1).
