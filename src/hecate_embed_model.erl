%%% @doc gen_server holding one loaded embedding model.
%%%
%%% Two backends:
%%%
%%%   nif    — Rustler NIF over fastembed-rs (production target).
%%%            Loads an ONNX session into a NIF resource handle.
%%%
%%%   ollama — HTTP POST to a local Ollama daemon's /api/embeddings.
%%%            No NIF, no Rust toolchain needed. Picked when fastembed-rs
%%%            isn't built yet, or when a different model is wanted.
%%%
%%% Backend is set per-model via `Opts#{backend => nif | ollama}'.
%%% Defaults to the `backend' env (which defaults to `nif').
%%%
%%% (A third backend, `remote' — HTTP to a hecate_embed instance run as its
%%% own service — existed and was removed: it had no callers anywhere in the
%%% workspace, and the topology that would have justified it doesn't occur —
%%% see hecate-embed CHANGELOG.)
-module(hecate_embed_model).
-behaviour(gen_server).

-export([
    start_link/2,
    stop/1,
    embed/2,
    embed_query/2,
    embed_passage/2,
    embed_many/2,
    dim/1,
    model_id/1,
    backend/1
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    name       :: atom(),
    model_id   :: binary(),
    dim        :: pos_integer(),
    backend    :: nif | ollama,
    handle     :: reference() | undefined,
    ollama_url :: string() | undefined
}).

start_link(Name, Opts) when is_atom(Name), is_map(Opts) ->
    gen_server:start_link({local, Name}, ?MODULE, {Name, Opts}, []).

stop(Ref) -> gen_server:stop(Ref).

embed(Ref, Text) -> gen_server:call(Ref, {embed, Text}, 60_000).
embed_query(Ref, Text) -> gen_server:call(Ref, {embed_query, Text}, 60_000).
embed_passage(Ref, Text) -> gen_server:call(Ref, {embed_passage, Text}, 60_000).
embed_many(Ref, Texts) -> gen_server:call(Ref, {embed_many, Texts}, 120_000).
dim(Ref) -> gen_server:call(Ref, dim).
model_id(Ref) -> gen_server:call(Ref, model_id).
backend(Ref) -> gen_server:call(Ref, backend).

init({Name, Opts}) ->
    ModelId = maps:get(model_id, Opts, default_model_id()),
    Dim     = maps:get(dim,      Opts, default_dim()),
    Backend = maps:get(backend,  Opts, default_backend()),
    init_backend(Backend, Name, ModelId, Dim, Opts).

init_backend(ollama, Name, ModelId, Dim, Opts) ->
    ok = ensure_inets(),
    Url = maps:get(ollama_url, Opts, default_ollama_url()),
    {ok, #state{name = Name, model_id = ModelId, dim = Dim,
                backend = ollama, ollama_url = Url}};
init_backend(nif, Name, ModelId, Dim, Opts) ->
    ModelDir = maps:get(model_dir, Opts, default_model_dir()),
    init_nif_loaded(hecate_embed_nif:load(ModelId, Dim, to_binary(ModelDir)),
                    Name, ModelId, Dim).

init_nif_loaded({ok, Handle}, Name, ModelId, Dim) ->
    {ok, #state{name = Name, model_id = ModelId, dim = Dim,
                backend = nif, handle = Handle}};
init_nif_loaded({error, Reason}, _Name, _ModelId, _Dim) ->
    {stop, {load_failed, Reason}}.

handle_call({embed, Text}, _From, #state{backend = nif, handle = H} = S) ->
    {reply, hecate_embed_nif:embed(H, Text), S};
handle_call({embed, Text}, _From, #state{backend = ollama} = S) ->
    {reply, ollama_embed(S, Text), S};

%% Asymmetric retrieval: e5-family models need the query text and the stored
%% passages embedded with different instruction prefixes. Apply the prefix, then
%% delegate to the raw {embed, _} path above (either backend).
handle_call({embed_query, Text}, From, #state{model_id = M} = S) ->
    handle_call({embed, prepend(query_prefix(M), Text)}, From, S);
handle_call({embed_passage, Text}, From, #state{model_id = M} = S) ->
    handle_call({embed, prepend(passage_prefix(M), Text)}, From, S);

handle_call({embed_many, Texts}, _From, #state{backend = nif, handle = H} = S) ->
    {reply, hecate_embed_nif:embed_many(H, Texts), S};
handle_call({embed_many, Texts}, _From, #state{backend = ollama} = S) ->
    {reply, ollama_embed_many(S, Texts), S};

handle_call(dim, _From, #state{dim = D} = S) ->
    {reply, D, S};
handle_call(model_id, _From, #state{model_id = M} = S) ->
    {reply, M, S};
handle_call(backend, _From, #state{backend = B} = S) ->
    {reply, B, S};
handle_call(_Other, _From, S) ->
    {reply, {error, unknown_call}, S}.

handle_cast(_, S) -> {noreply, S}.
handle_info(_, S) -> {noreply, S}.
terminate(_, _) -> ok.

%%% Internals — env

default_model_id() ->
    application:get_env(hecate_embed, default_model_id, <<"intfloat/multilingual-e5-small">>).

default_dim() ->
    application:get_env(hecate_embed, default_dim, 384).

%% Prefer the environment (HECATE_EMBED_MODEL_DIR) so the service configures the
%% baked model path without RELX_REPLACE_OS_VARS; fall back to the app-env.
default_model_dir() ->
    case os:getenv("HECATE_EMBED_MODEL_DIR") of
        Dir when is_list(Dir), Dir =/= "" -> Dir;
        _Unset -> application:get_env(hecate_embed, model_dir, "priv/models")
    end.

default_backend() ->
    application:get_env(hecate_embed, backend, nif).

default_ollama_url() ->
    application:get_env(hecate_embed, ollama_url, "http://127.0.0.1:11434/api/embeddings").

%% The NIF's model_id and model_dir are rustler `String`s, which decode from an
%% Erlang binary (not a charlist). Everything handed to the NIF must be binary.
to_binary(B) when is_binary(B) -> B;
to_binary(L) when is_list(L)   -> list_to_binary(L).

%%% Internals — asymmetric-retrieval prefixes

query_prefix(ModelId)   -> element(1, retrieval_prefixes(ModelId)).
passage_prefix(ModelId) -> element(2, retrieval_prefixes(ModelId)).

%% e5-family models (e.g. intfloat/multilingual-e5-small) require "query: " on
%% the search text and "passage: " on stored documents for correct asymmetric
%% retrieval. Models without a known convention get no prefix.
retrieval_prefixes(ModelId) ->
    case binary:match(ModelId, <<"e5">>) of
        nomatch -> {<<>>, <<>>};
        _Found  -> {<<"query: ">>, <<"passage: ">>}
    end.

prepend(<<>>, Text)   -> Text;
prepend(Prefix, Text) -> <<Prefix/binary, Text/binary>>.

%%% Internals — ollama backend

%% inets must be up before httpc can do anything. The app's `applications'
%% list already includes it, so this is belt+braces for tests/scripts that
%% start the model gen_server directly without booting hecate_embed.
ensure_inets() ->
    case application:ensure_all_started(inets) of
        {ok, _} -> ok;
        _       -> ok
    end.

-spec ollama_embed(#state{}, binary()) -> {ok, [float()]} | {error, term()}.
ollama_embed(#state{ollama_url = Url, model_id = ModelId}, Text) when is_binary(Text) ->
    Body = iolist_to_binary(json:encode(#{
        <<"model">>  => ModelId,
        <<"prompt">> => Text
    })),
    Request = {Url, [], "application/json", Body},
    case httpc:request(post, Request, [{timeout, 60_000}], [{body_format, binary}]) of
        {ok, {{_, 200, _}, _Headers, RespBody}} ->
            decode_embedding(RespBody);
        {ok, {{_, Code, _Reason}, _Headers, RespBody}} ->
            {error, {http_status, Code, truncate(RespBody)}};
        {error, Reason} ->
            {error, {http_error, Reason}}
    end.

-spec ollama_embed_many(#state{}, [binary()]) -> {ok, [[float()]]} | {error, term()}.
ollama_embed_many(_S, []) ->
    {ok, []};
ollama_embed_many(S, [T | Rest]) ->
    case ollama_embed(S, T) of
        {ok, V}        -> append_vec(V, ollama_embed_many(S, Rest));
        {error, _} = E -> E
    end.

append_vec(V, {ok, Vs})     -> {ok, [V | Vs]};
append_vec(_, {error, _} = E) -> E.

decode_embedding(RespBody) ->
    try json:decode(RespBody) of
        #{<<"embedding">> := Vec} when is_list(Vec) ->
            {ok, Vec};
        Other ->
            {error, {malformed_response, Other}}
    catch
        Class:Reason ->
            {error, {decode_failed, Class, Reason}}
    end.

truncate(B) when is_binary(B), byte_size(B) > 200 ->
    <<Head:200/binary, _/binary>> = B,
    Head;
truncate(B) -> B.
