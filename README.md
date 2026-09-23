# mcl-embed

Local, multilingual sentence embedder for the BEAM, as a Rust NIF.

A thin Erlang/OTP wrapper around a Rust embedder
([`fastembed`](https://github.com/Anush008/fastembed-rs) running ONNX models
locally) exposed via Rustler NIFs. No OpenAI dependency, no outbound calls
unless you fetch a model. Ships alongside a deterministic hash stub used only
for fast, download-free tests.

## Status

**Production.** The real ONNX backend is wired via `fastembed` (v5) and is what
the release containers ship — `multilingual-e5-small`, 384-dim, genuine
sentence embeddings. Retrieval quality is real, not scaffold.

Two build modes, selected by the `real-embed` cargo feature:

| Mode | Feature | Backend | Used by |
|------|---------|---------|---------|
| **real** | `real-embed` | `fastembed` ONNX (`multilingual-e5-small`) | `mcl-embedder`'s release container |
| **stub** | default (off) | deterministic hash (FNV-1a + splitmix64), L2-normalised 384-dim | library CI / consumer eunit — wiring tests, no ONNX, no download |

The stub returns stable per-input vectors so the rest of the stack integrates
and tests deterministically; it is useless for retrieval quality and never
shipped. The NIF is a pure embedder — model-specific conventions (e5's
`query:`/`passage:` prefixes) live in the Erlang layer.

## Why

- Sovereign stack: pure-Rust embedder, ONNX runtime, no Big Tech in the data path
- Multilingual default (NL / FR / DE / IT / EN) — matches the
  "Europe, not US" anchor
- BEAM-native: Rustler NIF, no sidecar, no IPC tax
- A pure library, no release of its own — served on the Macula mesh by
  [`mcl-embedder`](https://github.com/macula-services/mcl-embedder),
  the only consumer

## Public API

```erlang
{ok, Model} = mcl_embed:load_model(default, #{}).
{ok, Vec}   = mcl_embed:embed(Model, <<"the dossier moves through desks">>).
{ok, Vecs}  = mcl_embed:embed_many(Model, [<<"text1">>, <<"text2">>]).
Dim         = mcl_embed:dim(Model).  %% 384 by default
```

For asymmetric retrieval (e5 and similar), embed the stored side and the search
side differently — the facade applies the model's instruction prefix for you:

```erlang
{ok, PVec} = mcl_embed:embed_passage(Model, <<"rotate the leaked credential">>).
{ok, QVec} = mcl_embed:embed_query(Model, <<"what do I do about a leak?">>).
```

Vectors are lists of floats, length = `dim/1`. `embed/2` is safe to
call concurrently per `Model`; inference runs on a DirtyCpu scheduler so a
multi-millisecond embed never blocks a normal BEAM scheduler.

## Default model

`multilingual-e5-small` (intfloat) — 384-dim, ~100M params, ONNX format,
Apache-2.0 weights. Handles 100+ languages, including all 4 official
languages of Belgium.

Supported model ids (`resolve_model` in the NIF):

| model_id | dim |
|----------|-----|
| `intfloat/multilingual-e5-small` | 384 |
| `sentence-transformers/all-MiniLM-L6-v2` | 384 |

## Requirements

⚠ **The real backend needs a CPU with AVX2.** The ONNX Runtime that
`fastembed` links is built for AVX2, and on a CPU without it (the Celeron J4105
nodes, for example) the NIF dies with SIGILL the first time a model runs, taking
the node with it. The stub backend runs anywhere. Run the real one on an AVX2
host and reach it over the mesh, which is what `mcl-embedder` is for.

Building needs a Rust toolchain (`cargo`); the NIF is compiled from source
wherever this library is compiled.

## Installation

```erlang
{deps, [{mcl_embed, "~> 0.1"}]}.
```

The NIF builds as part of compiling this dependency (its own `pre_hooks` run
`scripts/build-nif.sh`), so a consumer adds nothing to its own hooks.

- `CARGO_FEATURES=real-embed` in the build environment builds the real
  `fastembed`/ONNX embedder.
- Unset, it builds the deterministic hash stub: right shape, no meaning, for
  tests.

The real backend needs the model files at run time:
`scripts/prefetch-model.sh` downloads the default model, and
`MCL_EMBED_MODEL_DIR` points the library at them.

## Architecture

| Module | Role |
|---|---|
| `mcl_embed` | the public facade |
| `mcl_embed_model` | one gen_server per loaded model |
| `mcl_embed_nif` | the Rustler NIF's Erlang side |
| `native/mcl_embed_nif/` | the Rust crate: fastembed, or the hash stub |

## Build and test

```bash
rebar3 compile                                   # builds the stub NIF too
CARGO_FEATURES=real-embed rebar3 compile         # builds the real ONNX NIF
rebar3 ct                                        # Common Test suites
rebar3 ex_doc                                    # docs
```

`rustler` and `rebar3_cargo` are deliberately not rebar deps: they pull in
mix-only transitives. `scripts/build-nif.sh` calls `cargo` directly.

## License

Apache-2.0. See [LICENSE](LICENSE).
