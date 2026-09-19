#!/bin/bash
#
# Cross-builds the fully static Linux binaries from macOS and packages them into dist/
#
# Requires the Swift Static Linux SDK:
#
#   swift sdk install https://download.swift.org/swift-6.4.0-release/static-sdk/...  (see swift.org)
#
# The SDK must be driven by the matching swift.org toolchain, NOT the one inside Xcode. Xcode's
# compiler rejects the SDK's prebuilt modules with "compiled module was created by a different
# version of the compiler". We therefore invoke the toolchain binary directly, which also side-
# steps swiftly's shims and any .swift-version file that might pin an uninstalled toolchain.
#
# Set SWIFT=/path/to/swift to override the auto-detected toolchain.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

VERSION="$(sed -n 's/.*versionNumbers = \[\(.*\)\].*/\1/p' Sources/trailer/Core/Config.swift | tr -d ' ' | tr ',' '.')"
if [ -z "$VERSION" ]; then
    echo "error: could not read the version from Sources/trailer/Core/Config.swift" >&2
    exit 1
fi

SWIFT="${SWIFT:-$(ls -d "$HOME"/Library/Developer/Toolchains/swift-*-RELEASE.xctoolchain/usr/bin/swift 2>/dev/null | sort -V | tail -1)}"
if [ -z "$SWIFT" ] || [ ! -x "$SWIFT" ]; then
    echo "error: no swift.org toolchain found in ~/Library/Developer/Toolchains" >&2
    echo "       install one (swiftly install, or a package from swift.org) or set SWIFT=/path/to/swift" >&2
    exit 1
fi
OBJCOPY="$(dirname "$SWIFT")/llvm-objcopy"

echo "==> Toolchain: $("$SWIFT" --version | head -1)"

if ! "$SWIFT" sdk list 2>/dev/null | grep -q 'static-linux'; then
    echo "error: the Swift Static Linux SDK is not installed for this toolchain" >&2
    echo "       see https://www.swift.org/documentation/articles/static-linux-getting-started.html" >&2
    exit 1
fi

# file(1) reports a different architecture string than the SDK triple uses.
arch_pattern() {
    case "$1" in
        x86_64) echo 'x86-64' ;;
        aarch64) echo 'ARM aarch64' ;;
    esac
}

for ARCH in x86_64 aarch64; do
    NAME="trailer-$VERSION-linux-$ARCH"
    STAGE="$ROOT/dist/$NAME"
    BUILD_ARGS=(-c release --swift-sdk "$ARCH-swift-linux-musl" -Xswiftc -Ounchecked)

    echo "==> Building $NAME"
    "$SWIFT" build "${BUILD_ARGS[@]}"
    BIN="$("$SWIFT" build "${BUILD_ARGS[@]}" --show-bin-path)/trailer"

    echo "==> Staging"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    cp "$BIN" "$STAGE/trailer"
    cp LICENSE "$STAGE/"

    # Almost all of the ~155MB of an unstripped build is debug information carried in the SDK's
    # prebuilt static archives. `-Xswiftc -gnone` does not remove it; only stripping does.
    "$OBJCOPY" --strip-all "$STAGE/trailer"

    echo "==> Verifying"
    file "$STAGE/trailer"
    file "$STAGE/trailer" | grep -q 'statically linked' || {
        echo "error: $NAME is not statically linked" >&2
        exit 1
    }
    file "$STAGE/trailer" | grep -q "$(arch_pattern "$ARCH")" || {
        echo "error: $NAME is not $ARCH" >&2
        exit 1
    }

    echo "==> Packaging"
    rm -f "$ROOT/dist/$NAME.tar.gz"
    tar -C "$ROOT/dist" -czf "$ROOT/dist/$NAME.tar.gz" "$NAME"
    rm -rf "$STAGE"

    (cd "$ROOT/dist" && shasum -a 256 "$NAME.tar.gz" | tee "$NAME.tar.gz.sha256")
done

ls -lh "$ROOT/dist"/trailer-"$VERSION"-linux-*.tar.gz

cat <<'EOF'

Note: these binaries cannot be executed on macOS. To actually run them, use Docker (Colima
provides the amd64 emulation) against both a musl and a glibc distro, for example:

  docker run --rm --platform linux/amd64 -v "$PWD/dist/<dir>":/x:ro debian:stable-slim /x/trailer -version

Static linking does not bundle CA certificates, so HTTPS fails on minimal images which lack the
ca-certificates package. That is expected, and not a fault in the binary.
EOF
