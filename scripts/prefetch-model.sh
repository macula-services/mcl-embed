#!/usr/bin/env bash
# Bake the embedding model into the image at build time, so the service never
# downloads at runtime (nothing leaves the box in production). Loads the model
# once via the real-embed NIF, which downloads the ONNX + tokenizer files into
# MODEL_DIR; that directory is then copied into the runtime image and found on
# boot via with_cache_dir (no re-download).
#
# Requires: scripts/build-nif.sh already run with CARGO_FEATURES=real-embed, and
# `rebar3 compile' done (the mcl_embed beams on the path).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MODEL_DIR="${1:-/models}"
MODEL_ID="${MCL_EMBED_MODEL:-intfloat/multilingual-e5-small}"

mkdir -p "$MODEL_DIR"
cd "$ROOT"

erl -noshell \
    -pa _build/default/lib/mcl_embed/ebin \
    -eval "case mcl_embed_nif:load(list_to_binary(\"${MODEL_ID}\"), 384, list_to_binary(\"${MODEL_DIR}\")) of {ok, _} -> io:format(\"prefetched ${MODEL_ID} into ${MODEL_DIR}~n\"); Err -> io:format(standard_error, \"prefetch failed: ~p~n\", [Err]), halt(1) end" \
    -s init stop
