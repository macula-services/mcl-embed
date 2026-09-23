# Contributing

Trunk-based. Commit directly to `main`. No PRs, no feature branches.

## Local build

```bash
rebar3 compile
rebar3 ct
```

The Rust NIF builds out of `native/mcl_embed_nif/`. You need:
- Erlang/OTP 26+
- Rust 1.70+ (stable)

## Style

- Erlang: `warnings_as_errors`, `dialyzer` clean
- Rust: `cargo clippy -- -D warnings`
- Vertical slicing only.

## Reporting issues

https://github.com/macula-services/mcl-embed/issues
