%%% @doc mcl_embed OTP application entry point.
-module(mcl_embed_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    mcl_embed_sup:start_link().

stop(_State) ->
    ok.
