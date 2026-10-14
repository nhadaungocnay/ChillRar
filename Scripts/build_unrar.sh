#!/usr/bin/env bash
# Build the official RARLAB UnRAR sources as a static library (libunrar.a)
# targeting Apple Silicon (arm64) with NEON/AES crypto enabled.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Vendor/unrar"
OUT="$ROOT/Vendor/lib"
MIN_MACOS="${MIN_MACOS:-13.0}"
JOBS="$(sysctl -n hw.ncpu)"

if [[ ! -f "$SRC/dll.cpp" ]]; then
  echo "UnRAR source not found in $SRC" >&2
  echo "Download: curl -L https://www.rarlab.com/rar/unrarsrc-7.3.1.tar.gz | tar -xz -C Vendor" >&2
  exit 1
fi

mkdir -p "$OUT"
cd "$SRC"
make clean >/dev/null 2>&1 || true

CXXFLAGS="-O2 -std=c++11 -arch arm64 -mcpu=apple-m1 -mmacosx-version-min=$MIN_MACOS \
-Wno-logical-op-parentheses -Wno-switch -Wno-dangling-else -fPIC"

# Build only the static archive (the makefile's 'lib' target also tries to
# produce a Linux style .so, which we don't need).
make -j"$JOBS" lib \
  CXXFLAGS="$CXXFLAGS" \
  LIBFLAGS="" \
  LDFLAGS="-pthread -arch arm64 -mmacosx-version-min=$MIN_MACOS" \
  >/dev/null 2> "$OUT/build.log" || { cat "$OUT/build.log" >&2; exit 1; }

cp libunrar.a "$OUT/libunrar.a"
make clean >/dev/null 2>&1 || true
echo "Built $OUT/libunrar.a ($(lipo -archs "$OUT/libunrar.a"))"
