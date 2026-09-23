//! mcl_embed_nif
//!
//! Rustler NIF backing `mcl_embed`. Two build modes, selected by the
//! `real-embed` cargo feature:
//!
//!   default        — a deterministic hash stub (FNV-1a + splitmix64) that
//!                    returns a stable, L2-normalised vector per input. Useless
//!                    for retrieval quality, useful for wiring tests, and pulls
//!                    in no ONNX runtime so library CI stays fast.
//!
//!   real-embed     — genuine sentence embeddings via `fastembed` (ONNX). The
//!                    consumer (mcl-embedder) builds with this feature on.
//!
//! Both modes present the same NIF surface: `load/3`, `embed/2`, `embed_many/2`.
//! Inference runs on a DirtyCpu scheduler so a multi-millisecond embed never
//! blocks a normal BEAM scheduler. The NIF is a pure embedder: model-specific
//! conventions (e5 query:/passage: prefixes) live in the Erlang layer that knows
//! which model is loaded.

use rustler::{Binary, Encoder, Env, NifResult, ResourceArc, Term};
use std::sync::Mutex;

mod atoms {
    rustler::atoms! { ok, error }
}

struct ModelResource {
    inner: Mutex<ModelInner>,
}

// ===================================================================
// real-embed backend: fastembed / ONNX
// ===================================================================

#[cfg(feature = "real-embed")]
struct ModelInner {
    model: fastembed::TextEmbedding,
    #[allow(dead_code)]
    dim: usize,
}

#[cfg(feature = "real-embed")]
fn build_model(model_id: &str, _dim: usize, model_dir: &str) -> Result<ModelInner, String> {
    use fastembed::{TextEmbedding, TextInitOptions};
    let (model_enum, dim) = resolve_model(model_id)?;
    let opts = TextInitOptions::new(model_enum).with_cache_dir(model_dir.into());
    let model = TextEmbedding::try_new(opts).map_err(|e| e.to_string())?;
    Ok(ModelInner { model, dim })
}

#[cfg(feature = "real-embed")]
fn resolve_model(model_id: &str) -> Result<(fastembed::EmbeddingModel, usize), String> {
    use fastembed::EmbeddingModel::{AllMiniLML6V2, MultilingualE5Small};
    match model_id {
        "intfloat/multilingual-e5-small" => Ok((MultilingualE5Small, 384)),
        "sentence-transformers/all-MiniLM-L6-v2" => Ok((AllMiniLML6V2, 384)),
        other => Err(format!("unsupported model_id: {other}")),
    }
}

#[cfg(feature = "real-embed")]
fn embed_texts(inner: &mut ModelInner, texts: Vec<&str>) -> Result<Vec<Vec<f32>>, String> {
    let owned: Vec<String> = texts.into_iter().map(|s| s.to_string()).collect();
    inner.model.embed(owned, None).map_err(|e| e.to_string())
}

// ===================================================================
// default backend: deterministic hash stub
// ===================================================================

#[cfg(not(feature = "real-embed"))]
struct ModelInner {
    dim: usize,
}

#[cfg(not(feature = "real-embed"))]
fn build_model(_model_id: &str, dim: usize, _model_dir: &str) -> Result<ModelInner, String> {
    Ok(ModelInner { dim })
}

#[cfg(not(feature = "real-embed"))]
fn embed_texts(inner: &mut ModelInner, texts: Vec<&str>) -> Result<Vec<Vec<f32>>, String> {
    Ok(texts.into_iter().map(|t| embed_one(t.as_bytes(), inner.dim)).collect())
}

/// Deterministic stub embedder: FNV-1a over the bytes, then a splitmix64 PRNG
/// expansion to `dim` floats in [-1, 1], L2-normalised so cosine is well-behaved.
#[cfg(not(feature = "real-embed"))]
fn embed_one(text: &[u8], dim: usize) -> Vec<f32> {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in text {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    let mut out = Vec::with_capacity(dim);
    let mut state = h;
    for _ in 0..dim {
        state = state.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = state;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
        z ^= z >> 31;
        let f = ((z as f64) / (u64::MAX as f64)) * 2.0 - 1.0;
        out.push(f as f32);
    }
    let norm: f32 = out.iter().map(|x| x * x).sum::<f32>().sqrt();
    if norm > 0.0 {
        for x in &mut out {
            *x /= norm;
        }
    }
    out
}

// ===================================================================
// NIF surface (identical for both backends)
// ===================================================================

#[rustler::nif(schedule = "DirtyCpu")]
fn load<'a>(env: Env<'a>, model_id: String, dim: usize, model_dir: String) -> NifResult<Term<'a>> {
    match build_model(&model_id, dim, &model_dir) {
        Ok(inner) => {
            let r = ResourceArc::new(ModelResource { inner: Mutex::new(inner) });
            Ok((atoms::ok(), r).encode(env))
        }
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn embed<'a>(env: Env<'a>, handle: ResourceArc<ModelResource>, text: Binary<'a>) -> NifResult<Term<'a>> {
    let mut guard = handle.inner.lock().unwrap();
    let s = std::str::from_utf8(text.as_slice()).unwrap_or("");
    match embed_texts(&mut guard, vec![s]) {
        Ok(mut vecs) => Ok((atoms::ok(), vecs.pop().unwrap_or_default()).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn embed_many<'a>(env: Env<'a>, handle: ResourceArc<ModelResource>, texts: Vec<Binary<'a>>) -> NifResult<Term<'a>> {
    let mut guard = handle.inner.lock().unwrap();
    let strs: Vec<&str> = texts
        .iter()
        .map(|t| std::str::from_utf8(t.as_slice()).unwrap_or(""))
        .collect();
    match embed_texts(&mut guard, strs) {
        Ok(vecs) => Ok((atoms::ok(), vecs).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

impl rustler::Resource for ModelResource {}

fn on_load(env: Env, _info: Term) -> bool {
    env.register::<ModelResource>().is_ok()
}

rustler::init!("mcl_embed_nif", load = on_load);
