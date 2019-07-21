#!/bin/bash -xe

: "${ARCH:=armhf}"
: "${TARGET:=armv7-unknown-linux-gnueabihf}"
: "${TARGET_CC:=arm-linux-gnueabihf-gcc}"

cargo check

podman run --interactive --rm --volume $PWD:/src rust:latest /bin/bash -xe <<EOF

export DEBIAN_FRONTEND="noninteractive"

dpkg --add-architecture ${ARCH}
apt-get update
apt-get install --yes --no-install-recommends crossbuild-essential-${ARCH} zlib1g-dev:${ARCH} libssl-dev:${ARCH} libsqlite3-dev:${ARCH}

export CARGO_TARGET_DIR="target-crossbuild-${ARCH}"
export PKG_CONFIG_ALLOW_CROSS=1
export RUSTFLAGS="-C linker=${TARGET_CC}"
export TARGET_CC="${TARGET_CC}"

cd /src
rustup target add ${TARGET}
cargo build --no-default-features --release --target=${TARGET}

EOF
