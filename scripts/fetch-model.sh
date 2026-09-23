#!/usr/bin/env bash
#
# Download the default ONNX model into priv/models/.
# Placeholder: not yet wired to a real source. When fastembed-rs is in,
# the fastembed crate fetches its own models — this script becomes
# optional, used only for air-gapped installs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MODELS="$ROOT/priv/models"

mkdir -p "$MODELS"

echo "TODO: fetch intfloat/multilingual-e5-small ONNX bundle into $MODELS"
echo "Until fastembed-rs is wired in, mcl_embed runs the deterministic"
echo "stub embedder, which needs no model files."
