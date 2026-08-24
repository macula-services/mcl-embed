# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed
- The standalone per-node "hecate-embed as its own HTTP service" mode:
  `hecate_embed_server`, `hecate_embed_http`, the `remote` backend on
  `hecate_embed_model` (client side), the `http_port`/`remote_url` app-env
  keys, the release/Containerfile/CI that built and pushed it to ghcr. It
  had zero consumers anywhere in the workspace, and the one scenario that
  would have justified it (multiple co-located minds on one box sharing a
  loaded model over loopback) doesn't occur: the boxes that run multiple
  minds per host have no AVX and can't run this NIF at all, and the one box
  that can run it already runs a single `hecate-embedder` mesh instance
  covering the whole realm. hecate-embed is now purely a library.

### Added
- Initial scaffold: Rustler NIF skeleton, gen_server-per-model, facade,
  Common Test smoke suite, build script.
- Deterministic hash-based stub embedder (correct shape, garbage
  semantics) so the rest of the stack can integrate before fastembed-rs
  is wired.

### Planned
- Swap stub for `fastembed-rs` running ONNX `multilingual-e5-small`
- Tokeniser caching
- Batched inference with dirty schedulers

## [0.1.0] - YYYY-MM-DD

_Not yet released._
