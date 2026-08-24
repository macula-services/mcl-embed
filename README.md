# hecate-embed

Local, multilingual sentence embedder for the Hecate ecosystem.

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
| **real** | `real-embed` | `fastembed` ONNX (`multilingual-e5-small`) | `hecate-embedder`'s release container |
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
  [`hecate-embedder`](https://github.com/hecate-services/hecate-embedder),
  the only consumer

## Public API

```erlang
{ok, Model} = hecate_embed:load_model(default, #{}).
{ok, Vec}   = hecate_embed:embed(Model, <<"the dossier moves through desks">>).
{ok, Vecs}  = hecate_embed:embed_many(Model, [<<"text1">>, <<"text2">>]).
Dim         = hecate_embed:dim(Model).  %% 384 by default
```

For asymmetric retrieval (e5 and similar), embed the stored side and the search
side differently — the facade applies the model's instruction prefix for you:

```erlang
{ok, PVec} = hecate_embed:embed_passage(Model, <<"rotate the leaked credential">>).
{ok, QVec} = hecate_embed:embed_query(Model, <<"what do I do about a leak?">>).
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

## Architecture

```
hecate_embed              ← public facade
  └── hecate_embed_model  ← gen_server per loaded model
        └── hecate_embed_nif ← Rustler NIF
              └── native/hecate_embed_nif/  ← Rust crate (fastembed / hash stub)
```

## Build

```bash
rebar3 compile                                # BEAM code
scripts/build-nif.sh                          # builds the stub NIF (default)
CARGO_FEATURES=real-embed scripts/build-nif.sh  # builds the real ONNX NIF
scripts/prefetch-model.sh                     # downloads the default model (real-embed only)
rebar3 ct                                     # Common Test suites
```

The NIF is built by `scripts/build-nif.sh` (which calls `cargo` directly);
`rustler`/`rebar3_cargo` are intentionally not rebar deps — they pull in
mix-only transitives.

## License

Apache-2.0. See [LICENSE](LICENSE).
