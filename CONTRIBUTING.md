# Contributing to sonde

Thanks for your interest in contributing to sonde!

## Getting started

```bash
git clone https://github.com/ronrefael/sonde && cd sonde

# Rust statusline
cargo build
cargo test
echo '{"model":{"display_name":"Opus"}}' | cargo run

# macOS menu bar app
cd SondeApp && make bundle && open build/Sonde.app
```

## Project structure

- `src/` — Rust terminal statusline binary
- `SondeApp/` — Swift macOS menu bar app
- `assets/` — logos, screenshots
- `scripts/` — build tooling

## Code style

- Rust: `cargo fmt` and `cargo clippy -- -D warnings` must pass
- Swift: follow existing patterns in the codebase

## Pull requests

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Ensure `cargo test` and `cargo clippy -- -D warnings` pass
4. Submit a PR with a clear description of what you changed and why

## Reporting bugs

Open an issue at https://github.com/ronrefael/sonde/issues with:
- What you expected to happen
- What actually happened
- Your OS and terminal (e.g. macOS 15, iTerm2)
- Output of `sonde doctor`

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
