# mcl_embed_nif

Rustler NIF crate backing the `mcl_embed` Erlang library.

This scaffold ships a **deterministic hash-based stub** — every input
text produces a stable, unit-norm `dim`-element vector. Useless for
semantic retrieval; useful as a placeholder while wiring the rest of
the stack.

## Swap-in plan

1. Add `fastembed = "4"` as a dep, gate under `real-embed` feature.
2. Replace `ModelInner` with `fastembed::TextEmbedding`.
3. Map `embed` → `model.embed(vec![text], None)?`, return first row.
4. Add tokeniser cache and dirty-scheduler annotations to `embed_many`.

## Build

```bash
cargo build --release
```
