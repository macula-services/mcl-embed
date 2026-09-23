%%% @doc mcl_embed public facade.
%%%
%%% Load one or more named embedding models, compute sentence
%%% embeddings, return as `[float()]'. Models are gen_servers
%%% wrapping a Rustler NIF resource (ONNX session).
-module(mcl_embed).

-export([
    load_model/2,
    unload_model/1,
    default_model/0,
    embed/1,
    embed/2,
    embed_query/2,
    embed_passage/2,
    embed_many/2,
    dim/1,
    model_id/1
]).

-export_type([model/0, vector/0]).

-type model()  :: pid() | atom().
-type vector() :: [float()].

%% @doc Load (or return existing) named model.
%%
%% Opts:
%%   model_id => binary()   (HuggingFace-style "org/name")
%%   dim      => pos_integer()
%%   model_dir => filename:filename_all()
-spec load_model(atom(), map()) -> {ok, model()} | {error, term()}.
load_model(Name, Opts) when is_atom(Name), is_map(Opts) ->
    case whereis(Name) of
        undefined -> mcl_embed_model_sup:start_model(Name, Opts);
        Pid       -> {ok, Pid}
    end.

-spec unload_model(model()) -> ok.
unload_model(M) -> mcl_embed_model:stop(M).

%% @doc Lazy default — loads `default' on first call.
-spec default_model() -> {ok, model()}.
default_model() -> load_model(default, #{}).

%% @doc Embed using the default model.
-spec embed(binary()) -> {ok, vector()} | {error, term()}.
embed(Text) when is_binary(Text) ->
    {ok, M} = default_model(),
    embed(M, Text).

-spec embed(model(), binary()) -> {ok, vector()} | {error, term()}.
embed(Model, Text) when is_binary(Text) ->
    mcl_embed_model:embed(Model, Text).

%% @doc Embed search text (adds the model's query instruction prefix, e.g. e5's
%% "query: "). Use for the recall side of asymmetric retrieval.
-spec embed_query(model(), binary()) -> {ok, vector()} | {error, term()}.
embed_query(Model, Text) when is_binary(Text) ->
    mcl_embed_model:embed_query(Model, Text).

%% @doc Embed a stored document (adds the model's passage instruction prefix,
%% e.g. e5's "passage: "). Use for the store side of asymmetric retrieval.
-spec embed_passage(model(), binary()) -> {ok, vector()} | {error, term()}.
embed_passage(Model, Text) when is_binary(Text) ->
    mcl_embed_model:embed_passage(Model, Text).

-spec embed_many(model(), [binary()]) -> {ok, [vector()]} | {error, term()}.
embed_many(Model, Texts) when is_list(Texts) ->
    mcl_embed_model:embed_many(Model, Texts).

-spec dim(model()) -> pos_integer().
dim(Model) -> mcl_embed_model:dim(Model).

-spec model_id(model()) -> binary().
model_id(Model) -> mcl_embed_model:model_id(Model).
