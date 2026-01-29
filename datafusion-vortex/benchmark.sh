#!/bin/bash

set -Eeuo pipefail

# Install Rust.
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install Dependencies.
sudo apt-get update -y
sudo apt-get install -y gcc jq build-essential

# Install Vortex from latest release main branch.
git clone https://github.com/vortex-data/vortex.git || true
cd vortex
git checkout 0.58.0
git submodule update --init

# Make sure to build the release version of the benchmark.
cargo build --release --package datafusion-bench --bin datafusion-bench

# Vortex's benchmarking utility generates appropriate Vortex files by itself (by downloading Parquet
# files and converting those into Vortex files), so we just run it once to make sure they exist
# before we start measuring timing.
echo -n "Load time: "
command time -f '%e' ./target/release/datafusion-bench clickbench \
    -i 1 \
    --formats vortex \
    -d gh-json \
    -q 0 \
    --hide-progress-bar \
    --opt flavor=single

# Run the benchmark for a single Vortex file (this will download a single Parquet file and convert).
# Note: run.sh must be run from within the `./vortex` directory so `workspace_root()` can find
# the `Cargo.lock` file.
../run.sh single

echo "Data size: $(find . -name "*.vortex" | xargs du -bc | awk 'END {print $1}')"
