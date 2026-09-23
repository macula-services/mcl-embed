# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-09-23

The first release on hex. Same code as the `v0.1.0` tag, plus the release
workflow: **`v0.1.0` exists as a git tag but was never published**, because it
was cut before this repository could release by tag.

### Added
- A tag releases: `publish-hex.yml` publishes a pushed `vX.Y.Z` tag to hex,
  after refusing unless the checkout is exactly that clean, pushed tag with a
  CHANGELOG section (`scripts/is_checkout_publishable.sh`), building a
  throwaway consumer against the packaged tarball alone to prove the NIF
  builds and loads from what hex will serve, and dry-running the publish. It
  then checks that hex serves the tagged code
  (`scripts/is_hex_serving_what_git_says.sh`).

## [0.1.0] - never published

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
