#!/usr/bin/env bash

set -euo pipefail

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$*\e[0m"
}

# Build LLVM
msg "Building LLVM..."
./build-llvm.py \
	--clang-vendor "Azure" \
	--projects "clang;lld;polly" \
	--targets "ARM;AArch64" \
	--shallow-clone \
	--incremental \
	--build-type "Release" \

# Build binutils
msg "Building binutils..."
./build-binutils.py --targets arm aarch64

# Remove unused products
msg "Removing unused products..."
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
msg "Setting library load paths for portability..."
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$ORIGIN/../lib" "$bin"
done