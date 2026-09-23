#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

cd "$ROOT/native/mcl_embed_nif"
# CARGO_FEATURES selects the embedder backend. Empty (default) builds the
# deterministic hash stub with no ONNX runtime; "real-embed" builds the real
# fastembed/ONNX embedder (the consumer, e.g. mcl-embedder, sets this).
cargo build --release ${CARGO_FEATURES:+--features "$CARGO_FEATURES"}

mkdir -p "$ROOT/priv/lib"
case "$(uname -s)" in
    Linux*)   ext=so ;;
    Darwin*)  ext=dylib ;;
    MINGW*|MSYS*|CYGWIN*) ext=dll ;;
    *) echo "Unsupported: $(uname -s)" >&2; exit 1 ;;
esac

src="$ROOT/native/mcl_embed_nif/target/release/libmcl_embed_nif.${ext}"
dst="$ROOT/priv/lib/libmcl_embed_nif.${ext}"
cp "$src" "$dst"
echo "Built: $dst"
