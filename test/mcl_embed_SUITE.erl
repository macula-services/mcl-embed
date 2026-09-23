%%% @doc Smoke tests for mcl_embed.
-module(mcl_embed_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([load_default/1, embed_is_deterministic/1, dim_matches/1, embed_many_roundtrip/1]).

all() ->
    [load_default, embed_is_deterministic, dim_matches, embed_many_roundtrip].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(mcl_embed),
    Config.

end_per_suite(_Config) ->
    application:stop(mcl_embed),
    ok.

load_default(_Config) ->
    {ok, M} = mcl_embed:load_model(t_default, #{}),
    ?assert(is_pid(M) orelse is_atom(M)),
    ok = mcl_embed:unload_model(M).

embed_is_deterministic(_Config) ->
    {ok, M} = mcl_embed:load_model(t_det, #{}),
    {ok, V1} = mcl_embed:embed(M, <<"hello world">>),
    {ok, V2} = mcl_embed:embed(M, <<"hello world">>),
    ?assertEqual(V1, V2),
    ok = mcl_embed:unload_model(M).

dim_matches(_Config) ->
    {ok, M} = mcl_embed:load_model(t_dim, #{dim => 128}),
    {ok, V} = mcl_embed:embed(M, <<"x">>),
    ?assertEqual(128, length(V)),
    ?assertEqual(128, mcl_embed:dim(M)),
    ok = mcl_embed:unload_model(M).

embed_many_roundtrip(_Config) ->
    {ok, M} = mcl_embed:load_model(t_many, #{dim => 16}),
    {ok, Vecs} = mcl_embed:embed_many(M, [<<"a">>, <<"b">>, <<"c">>]),
    ?assertEqual(3, length(Vecs)),
    [?assertEqual(16, length(V)) || V <- Vecs],
    ok = mcl_embed:unload_model(M).
