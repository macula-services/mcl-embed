# Getting started

`hecate_embed` computes sentence embeddings inside a running BEAM
node. The default model is multilingual (NL / FR / DE / IT / EN and
~100 others), produced by `intfloat/multilingual-e5-small`.

## Install

```erlang
%% rebar.config
{deps, [
    {hecate_embed, "~> 0.1"}
]}.
```

## Embed a single string

```erlang
{ok, M}   = hecate_embed:default_model().
{ok, Vec} = hecate_embed:embed(M, <<"de dossier reist langs balies"/utf8>>).
```

`Vec` is a list of `dim` floats. For the default model, `dim = 384`.

## Batch

```erlang
{ok, M}    = hecate_embed:default_model().
{ok, Vecs} = hecate_embed:embed_many(M, [
    <<"vertical slicing">>,
    <<"screaming architecture">>,
    <<"venture lifecycle">>
]).
```

Batched calls are recommended over one-at-a-time when you have more
than a handful of inputs; the NIF amortises tokeniser + ONNX setup
across the batch.

## Load a different model

```erlang
{ok, BigM} = hecate_embed:load_model(big, #{
    model_id => <<"intfloat/multilingual-e5-base">>,
    dim      => 768
}).
{ok, V}    = hecate_embed:embed(BigM, <<"text">>).
```

## Combining with a vector index

`hecate_vector` (the earlier in-BEAM ANN index this guide used to pair with)
is archived: it never grew past brute-force scan and nothing in the workspace
depends on it anymore. For storing and searching the vectors this library
produces, use [`barrel`](https://github.com/beam-campus/barrel)'s
`barrel_vectordb` (real HNSW/DiskANN) instead — that's what `hecate-rag`
switched to.

```erlang
{ok, M} = hecate_embed:default_model().
{ok, V} = hecate_embed:embed(M, <<"the dossier moves through desks">>).
%% hand V to barrel_vectordb (or let barrel's own embedding policy compute
%% it for you, see barrel's docs) — see barrel/docs/guides/ for the API.
```
