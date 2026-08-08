#!/usr/bin/env bash
#
# Build a universal (arm64 + x86_64) readsb binary for bundling into
# Skydex Feeder.app, statically linked against librtlsdr and libusb so the
# result is a single self-contained Mach-O (no dylib @rpath dance).
#
# macOS only. Requires: Xcode command line tools, cmake, autoconf,
# automake, libtool, pkg-config (brew install cmake autoconf automake
# libtool pkg-config).
#
# Output:
#   vendor/bin/readsb            universal binary, ad-hoc signed
#   vendor/licenses/             readsb / librtlsdr / libusb license texts
#
# Licensing note (verified against upstream 2026-08-08): readsb is
# GPL-3.0-or-later, librtlsdr is GPL-2.0-or-later, libusb is LGPL-2.1.
# "Or later" on librtlsdr is what makes the static link legal — the
# combined readsb *executable* is distributed under GPL-3.0. That's fine:
# we ship the license texts, publish sources + this build script in the
# public releases repo (es-ua/skydex-feeder), and readsb runs as a
# separate process, so the closed-source app itself stays unencumbered.
# The app never links any of these libraries.

set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
    echo "error: this script must run on macOS" >&2
    exit 1
fi

# Pinned versions — bump deliberately.
# libusb 1.0.30 is current; 1.0.27 predates several macOS fixes. Note this was
# NOT the cause of a "SDR wedged, exiting!" investigation on macOS 26 — the
# bump was tested against a stick that produced no samples and changed nothing
# (rtl_sdr captured 0 bytes off it too, so the fault was below libusb).
LIBUSB_VERSION="1.0.30"
LIBUSB_URL="https://github.com/libusb/libusb/releases/download/v${LIBUSB_VERSION}/libusb-${LIBUSB_VERSION}.tar.bz2"
ZSTD_VERSION="1.5.6"
ZSTD_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz"
RTLSDR_REF="v2.0.2"
RTLSDR_REPO="https://github.com/osmocom/rtl-sdr.git"
READSB_REF="latest"   # resolved to newest tag below; pin a tag for releases
READSB_REPO="https://github.com/wiedehopf/readsb.git"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/vendor/build"
OUT_BIN="$ROOT/vendor/bin"
OUT_LIC="$ROOT/vendor/licenses"
ARCHES=(arm64 x86_64)
JOBS="$(sysctl -n hw.ncpu)"
MACOS_MIN="13.0"

mkdir -p "$BUILD" "$OUT_BIN" "$OUT_LIC"

# --- fetch sources ---------------------------------------------------------

fetch() {
    local dir="$1"
    if [[ ! -d "$BUILD/$dir" ]]; then
        return 0
    fi
    return 1
}

cd "$BUILD"

if [[ ! -d "libusb-${LIBUSB_VERSION}" ]]; then
    echo "==> fetching libusb ${LIBUSB_VERSION}"
    curl -fL "$LIBUSB_URL" -o libusb.tar.bz2
    tar xjf libusb.tar.bz2
    rm libusb.tar.bz2
fi

if [[ ! -d "zstd-${ZSTD_VERSION}" ]]; then
    echo "==> fetching zstd ${ZSTD_VERSION}"
    curl -fL "$ZSTD_URL" -o zstd.tar.gz
    tar xzf zstd.tar.gz
    rm zstd.tar.gz
fi

if [[ ! -d rtl-sdr ]]; then
    echo "==> fetching rtl-sdr ${RTLSDR_REF}"
    git clone --depth 1 --branch "$RTLSDR_REF" "$RTLSDR_REPO" rtl-sdr
fi

if [[ ! -d readsb ]]; then
    echo "==> fetching readsb"
    git clone "$READSB_REPO" readsb
    if [[ "$READSB_REF" == "latest" ]]; then
        READSB_TAG="$(git -C readsb describe --tags --abbrev=0)"
    else
        READSB_TAG="$READSB_REF"
    fi
    git -C readsb checkout "$READSB_TAG"
    echo "==> readsb at $(git -C readsb describe --tags)"
fi

# --- per-arch builds -------------------------------------------------------

for ARCH in "${ARCHES[@]}"; do
    PREFIX="$BUILD/prefix-$ARCH"
    mkdir -p "$PREFIX"
    export CFLAGS="-arch $ARCH -mmacosx-version-min=$MACOS_MIN -O2"
    export LDFLAGS="-arch $ARCH -mmacosx-version-min=$MACOS_MIN"
    HOST_FLAG="$ARCH-apple-darwin"

    # libusb (static)
    if [[ ! -f "$PREFIX/lib/libusb-1.0.a" ]]; then
        echo "==> building libusb for $ARCH"
        pushd "libusb-${LIBUSB_VERSION}" >/dev/null
        make distclean >/dev/null 2>&1 || true
        ./configure --prefix="$PREFIX" --host="$HOST_FLAG" \
            --disable-shared --enable-static --disable-udev
        make -j"$JOBS"
        make install
        popd >/dev/null
    fi

    # zstd (static) — recent readsb links -lzstd; the brew dylib only
    # exists for the runner's own arch, so build our own per arch.
    if [[ ! -f "$PREFIX/lib/libzstd.a" ]]; then
        echo "==> building zstd for $ARCH"
        make -C "zstd-${ZSTD_VERSION}/lib" clean >/dev/null 2>&1 || true
        make -C "zstd-${ZSTD_VERSION}/lib" -j"$JOBS" libzstd.a CFLAGS="$CFLAGS"
        cp "zstd-${ZSTD_VERSION}/lib/libzstd.a" "$PREFIX/lib/"
        cp "zstd-${ZSTD_VERSION}/lib/zstd.h" "$PREFIX/include/"
        cp "zstd-${ZSTD_VERSION}/lib/zdict.h" "$PREFIX/include/" 2>/dev/null || true
        cp "zstd-${ZSTD_VERSION}/lib/zstd_errors.h" "$PREFIX/include/" 2>/dev/null || true
        mkdir -p "$PREFIX/lib/pkgconfig"
        cat > "$PREFIX/lib/pkgconfig/libzstd.pc" <<EOF
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: zstd
Description: static zstd for Skydex Feeder
Version: ${ZSTD_VERSION}
Libs: -L\${libdir} -lzstd
Cflags: -I\${includedir}
EOF
    fi

    # librtlsdr (static), against our static libusb.
    # rtl-sdr's CMake unconditionally creates both a shared and a static
    # target; the shared dylib fails to link against static libusb (its
    # IOKit/CoreFoundation/Security deps aren't on that link line), so we
    # build ONLY the static target and install it by hand, with a
    # hand-written .pc that carries the frameworks readsb's final link
    # needs.
    if [[ ! -f "$PREFIX/lib/librtlsdr.a" ]]; then
        echo "==> building librtlsdr for $ARCH"
        cmake -S rtl-sdr -B "rtl-sdr-build-$ARCH" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
            -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
            -DCMAKE_INSTALL_PREFIX="$PREFIX" \
            -DDETACH_KERNEL_DRIVER=OFF \
            -DLIBUSB_INCLUDE_DIRS="$PREFIX/include/libusb-1.0" \
            -DLIBUSB_LIBRARIES="$PREFIX/lib/libusb-1.0.a" \
            -DCMAKE_PREFIX_PATH="$PREFIX"
        cmake --build "rtl-sdr-build-$ARCH" -j"$JOBS" --target rtlsdr_static
        if [[ -f "rtl-sdr-build-$ARCH/src/librtlsdr.a" ]]; then
            cp "rtl-sdr-build-$ARCH/src/librtlsdr.a" "$PREFIX/lib/librtlsdr.a"
        else
            cp "rtl-sdr-build-$ARCH/src/librtlsdr_static.a" "$PREFIX/lib/librtlsdr.a"
        fi
        cp rtl-sdr/include/*.h "$PREFIX/include/"
        mkdir -p "$PREFIX/lib/pkgconfig"
        cat > "$PREFIX/lib/pkgconfig/librtlsdr.pc" <<EOF
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: RTL-SDR Library
Description: static librtlsdr for Skydex Feeder
Version: ${RTLSDR_REF#v}
Libs: -L\${libdir} -lrtlsdr -lusb-1.0 -framework IOKit -framework CoreFoundation -framework Security
Cflags: -I\${includedir}
EOF
        # Belt and suspenders: no dylibs may leak into the link.
        rm -f "$PREFIX"/lib/*.dylib
    fi

    # readsb.
    # Its Makefile assigns CFLAGS itself (env CFLAGS is ignored), so arch
    # selection goes through CC — which also covers the link step — and
    # extra compile flags through the documented OPTIMIZE hook, which lands
    # *after* the Makefile's -Werror. -Wno-error is needed because upstream
    # readsb has benign unused-parameter warnings on the macOS code path
    # (e.g. the Linux-only hugepages parameter). Include/lib paths come from
    # our hand-written librtlsdr.pc via PKG_CONFIG_PATH.
    echo "==> building readsb for $ARCH"
    pushd readsb >/dev/null
    make clean >/dev/null 2>&1 || true
    # -L$PREFIX/lib goes through CC so it lands FIRST on the link line:
    # readsb's Darwin Makefile adds -L/opt/homebrew/lib, and homebrew's
    # host-arch-only dylibs (libusb, zstd) must not shadow our per-arch
    # static libs when cross-linking the other half of the universal build.
    # The frameworks ride along for the same reason: static libusb needs
    # IOKit/CoreFoundation/Security explicitly (a dylib would carry them
    # itself), and readsb links -lusb-1.0 directly rather than through our
    # librtlsdr.pc Libs line. clang warns that -framework is unused during
    # compile steps — harmless.
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
        make -j"$JOBS" RTLSDR=yes \
            CC="cc -arch $ARCH -mmacosx-version-min=$MACOS_MIN -L$PREFIX/lib -framework IOKit -framework CoreFoundation -framework Security" \
            OPTIMIZE="-O2 -Wno-error"
    cp readsb "$BUILD/readsb-$ARCH"
    popd >/dev/null
done

# --- universal binary ------------------------------------------------------

echo "==> creating universal binary"
lipo -create "$BUILD/readsb-arm64" "$BUILD/readsb-x86_64" -output "$OUT_BIN/readsb"
chmod +x "$OUT_BIN/readsb"
lipo -info "$OUT_BIN/readsb"

# Ad-hoc sign for local development; CI re-signs with Developer ID +
# hardened runtime during app signing.
codesign --force --sign - "$OUT_BIN/readsb"

# --- license attribution ---------------------------------------------------

echo "==> collecting license texts"
cp "$BUILD/readsb/LICENSE" "$OUT_LIC/readsb-LICENSE.txt" 2>/dev/null \
    || cp "$BUILD/readsb/COPYING" "$OUT_LIC/readsb-LICENSE.txt"
cp "$BUILD/rtl-sdr/COPYING" "$OUT_LIC/librtlsdr-COPYING.txt"
cp "$BUILD/libusb-${LIBUSB_VERSION}/COPYING" "$OUT_LIC/libusb-COPYING.txt"

cat > "$OUT_LIC/README.txt" <<'EOF'
Skydex Feeder bundles the following third-party software as a separate
executable (Contents/Resources/bin/readsb):

  readsb    https://github.com/wiedehopf/readsb   GPL-3.0-or-later
  librtlsdr https://github.com/osmocom/rtl-sdr    GPL-2.0-or-later (statically linked into readsb)
  libusb    https://github.com/libusb/libusb      LGPL-2.1 (statically linked into readsb)

The readsb executable, as distributed here, is therefore covered by the
GPL-3.0 as a combined work. Full license texts are in this directory.
Source code for the exact versions used, together with the build script
that produces this binary, is published at:

  https://github.com/es-ua/skydex-feeder

The Skydex Feeder app itself does not link these libraries; it runs
readsb as a separate process.
EOF

echo "==> done: $OUT_BIN/readsb"
