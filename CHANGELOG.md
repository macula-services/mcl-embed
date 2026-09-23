# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - unreleased

First release on hex, as `mcl_embed`. The library was developed as
`hecate_embed` and never published under that name.

### Added
- `fastembed`/ONNX embedder (`real-embed` cargo feature),
  `multilingual-e5-small` by default, 384 dimensions.
- A deterministic hash stub (default build) with the same shape, for tests.
- `embed_query/2` and `embed_passage/2`, applying the model's asymmetric
  retrieval prefixes.
- The NIF builds from source wherever the app is compiled, including as a
  dependency (`pre_hooks`), and the Rust source ships in the hex package.
