#!/usr/bin/env bash
# Builds the GDExtension libraries into godot/bin/.
#   ./build.sh linux     -> libshogi_engine.linux.template_release.x86_64.so (headless tests)
#   ./build.sh android   -> arm64-v8a + x86_64 .so (needs the Android NDK r28+)
#   ./build.sh all
# The NDK comes from $ANDROID_NDK_ROOT; if unset, NDK r28c is downloaded to thirdparty/.
set -euo pipefail
cd "$(dirname "$0")"
./fetch_deps.sh

JOBS=$(nproc 2>/dev/null || echo 4)
NDK_VERSION=r28c

ensure_ndk() {
  if [ -n "${ANDROID_NDK_ROOT:-}" ] && [ -d "$ANDROID_NDK_ROOT" ]; then return; fi
  if [ ! -d "thirdparty/android-ndk-$NDK_VERSION" ]; then
    echo "Downloading Android NDK $NDK_VERSION..."
    curl -fSL -o thirdparty/ndk.zip "https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux.zip"
    unzip -q thirdparty/ndk.zip -d thirdparty && rm thirdparty/ndk.zip
  fi
  export ANDROID_NDK_ROOT="$PWD/thirdparty/android-ndk-$NDK_VERSION"
}

bindings() {
  [ -d thirdparty/godot-cpp/gen ] || python3 -I gen_bindings.py
}

build_linux() {
  bindings
  make -j"$JOBS" PLATFORM=linux ARCH=x86_64
}

build_android() {
  ensure_ndk
  bindings
  for arch in arm64 x86_64; do
    make -j"$JOBS" PLATFORM=android ARCH="$arch" ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT"
  done
}

case "${1:-all}" in
  linux) build_linux ;;
  android) build_android ;;
  all) build_linux; build_android ;;
  *) echo "usage: $0 [linux|android|all]"; exit 1 ;;
esac
ls -l ../bin/*.so
