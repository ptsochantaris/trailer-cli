#!/bin/bash
#
# Builds the redistributable macOS binary and packages it into dist/
#
# The result is a universal (arm64 + x86_64) binary. It is not statically linked, and cannot
# be: Apple ships no static libSystem. It does not need to be either, since the Swift runtime
# has been part of the OS since 10.14.4, so every library it links is already on the target
# machine. Note that `--static-swift-stdlib` is silently accepted here but has no effect.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

VERSION="$(sed -n 's/.*versionNumbers = \[\(.*\)\].*/\1/p' Sources/trailer/Core/Config.swift | tr -d ' ' | tr ',' '.')"
if [ -z "$VERSION" ]; then
    echo "error: could not read the version from Sources/trailer/Core/Config.swift" >&2
    exit 1
fi

NAME="trailer-$VERSION-macos-universal"
STAGE="$ROOT/dist/$NAME"

BUILD_ARGS=(-c release --arch arm64 --arch x86_64 -Xswiftc -Ounchecked)

echo "==> Building $NAME"
swift build "${BUILD_ARGS[@]}"
BIN="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/trailer"

echo "==> Staging"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$BIN" "$STAGE/trailer"
cp LICENSE "$STAGE/"

# Strip the copy rather than the build product, so an incremental rebuild is not disturbed.
strip "$STAGE/trailer"

echo "==> Verifying"
lipo -info "$STAGE/trailer"
lipo -info "$STAGE/trailer" | grep -q 'x86_64 arm64' || {
    echo "error: binary is not universal" >&2
    exit 1
}
"$STAGE/trailer" -mono -version | grep -q "$VERSION" || {
    echo "error: binary did not report version $VERSION" >&2
    exit 1
}

echo "==> Packaging"
rm -f "$ROOT/dist/$NAME.tar.gz"
tar -C "$ROOT/dist" -czf "$ROOT/dist/$NAME.tar.gz" "$NAME"
rm -rf "$STAGE"

cd "$ROOT/dist"
shasum -a 256 "$NAME.tar.gz" | tee "$NAME.tar.gz.sha256"
ls -lh "$NAME.tar.gz"
