#!/usr/bin/env bash

# Main
LLVM_NAME= # Your desired Toolchain Name
GH_USERNAME= # Your Github Username
GH_EMAIL= # Your Github Email
GH_TOKEN= # Your Github Token ( repo & repo_hook )
GH_PUSH_REPO_URL= # Your Repository for store compiled Toolchain ( without https:// or www. ) ex. github.com/xyz-prjkt/xRageTC.git

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

# Set a directory
DIR="$(pwd ...)"

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Send information
msg "<b>${LLVM_NAME}: Toolchain Compilation Started</b>%0A<b>Date : </b><code>$rel_friendly_date</code>%0A<b>Toolchain Script Commit : </b><code>$builder_commit</code>%0A"

# Build LLVM
msg "${LLVM_NAME}: Building LLVM..."
tg_post_msg "<b>${LLVM_NAME}: Building LLVM. . .</b>"
./build-llvm.py \
	--clang-vendor "${LLVM_NAME}" \
	--projects "clang;lld;polly" \
	--targets "ARM;AArch64" \
	--shallow-clone \
	--incremental \
	--build-type "Release" 2>&1 | tee build.log

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-1* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
	err "build.log" "Error Log"
	exit 1
}

# Build binutils
msg "${LLVM_NAME}: Building binutils..."
msg "<b>${LLVM_NAME}: Building Binutils. . .</b>"
./build-binutils.py --targets arm aarch64

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done

# Release Info
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

msg "<b>${LLVM_NAME}: Toolchain compilation Finished</b>%0A<b>Clang Version : </b><code>$clang_version</code>%0A<b>LLVM Commit : </b><code>$llvm_commit_url</code>%0A<b>Binutils Version : </b><code>$binutils_ver</code>"

# Push to GitHub
# Update Git repository
git config --global user.name ${GH_USERNAME}
git config --global user.email ${GH_EMAIL}
git clone "https://${GH_USERNAME}:${GH_TOKEN}@${GH_PUSH_REPO_URL}" rel_repo
pushd rel_repo || exit
rm -fr ./*
cp -r ../install/* .
git checkout README.md # keep this as it's not part of the toolchain itself
git add .
git commit -asm "${LLVM_NAME}: Bump to $rel_date build

LLVM commit: $llvm_commit_url
Clang Version: $clang_version
Binutils version: $binutils_ver
Builder commit: https://${GH_PUSH_REPO_URL}/commit/$builder_commit"
git push -f
popd || exit
msg "<b>${LLVM_NAME}: Toolchain pushed to <code>https://${GH_PUSH_REPO_URL}</code></b>"
