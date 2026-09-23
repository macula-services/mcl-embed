%%% @doc Dynamic supervisor for loaded models.
-module(mcl_embed_model_sup).
-behaviour(supervisor).

-export([start_link/0, start_model/2]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_model(Name, Opts) ->
    supervisor:start_child(?MODULE, [Name, Opts]).

init([]) ->
    SupFlags = #{
        strategy  => simple_one_for_one,
        intensity => 10,
        period    => 10
    },
    Children = [
        #{
            id       => mcl_embed_model,
            start    => {mcl_embed_model, start_link, []},
            restart  => transient,
            shutdown => 5000,
            type     => worker,
            modules  => [mcl_embed_model]
        }
    ],
    {ok, {SupFlags, Children}}.
