%%% @doc Rustler NIF entry for mcl_embed.
-module(mcl_embed_nif).

-export([load/3, embed/2, embed_many/2]).

-on_load(init/0).

-define(NIF_NOT_LOADED, erlang:nif_error({nif_not_loaded, ?MODULE})).

init() ->
    PrivDir = case code:priv_dir(mcl_embed) of
        {error, _} ->
            EbinDir = filename:dirname(code:which(?MODULE)),
            filename:join(filename:dirname(EbinDir), "priv");
        Dir ->
            Dir
    end,
    erlang:load_nif(filename:join([PrivDir, "lib", "libmcl_embed_nif"]), 0).

%% @doc Load a model. Returns an opaque handle. model_id and model_dir are
%% binaries (the Rust side decodes rustler `String' from an Erlang binary).
-spec load(binary(), pos_integer(), binary()) -> {ok, reference()} | {error, term()}.
load(_ModelId, _Dim, _ModelDir) -> ?NIF_NOT_LOADED.

%% @doc Embed a single text.
-spec embed(reference(), binary()) -> {ok, [float()]} | {error, term()}.
embed(_Handle, _Text) -> ?NIF_NOT_LOADED.

%% @doc Embed a batch.
-spec embed_many(reference(), [binary()]) -> {ok, [[float()]]} | {error, term()}.
embed_many(_Handle, _Texts) -> ?NIF_NOT_LOADED.
