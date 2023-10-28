#!/bin/bash -xe

: "${ARCH:=arm64}"
: "${TARGET:=aarch64-unknown-linux-gnu}"
: "${TARGET_CPU:=cortex-a53}"
: "${TARGET_CC:=aarch64-linux-gnu-gcc}"

cargo check

podman run --interactive --rm --volume $PWD:/src rust:bookworm /bin/bash -xe <<EOF

export DEBIAN_FRONTEND="noninteractive"

dpkg --add-architecture ${ARCH}
apt-get update
apt-get install --yes --no-install-recommends crossbuild-essential-${ARCH} zlib1g-dev:${ARCH} libssl-dev:${ARCH} libsqlite3-dev:${ARCH}

export CARGO_TARGET_DIR="target-crossbuild-${ARCH}"
export PKG_CONFIG_ALLOW_CROSS=1
export RUSTFLAGS="-Clinker=${TARGET_CC} -Ctarget-cpu=${TARGET_CPU}"
export TARGET_CC="${TARGET_CC}"

cd /src
rustup target add ${TARGET}
cargo build --no-default-features --release --target=${TARGET}

EOF
