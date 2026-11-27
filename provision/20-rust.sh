#!/bin/bash
# Rust via rustup (videoping needs Rust >= 1.92, edition 2024). Runs as user "vagrant".
set -euo pipefail
if [ ! -x "$HOME/.cargo/bin/cargo" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
fi
source "$HOME/.cargo/env"
rustup update stable
rustc --version
