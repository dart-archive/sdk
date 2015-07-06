#!/bin/bash

# Manual setup in xcode.
# Add $(PROJECT_DIR)/../../.. to Build Settings / Header Search Path
# Add $(PROJECT_DIR)/../generated to Build Settings / User Header Search Path
# Add out/ReleaseXARM/libfletch.a to Build Phases / Link Binary with Libraries
# Set 'no' in Build Settings / Dead Code Stripping
# Add directory group to objc and to cc in <FLETCH_ROOT>/package/immi_gen
# Add Resources directory reference to ./generated
# Add a "Run Script" with content ./compile.sh in Build Phases
# and place it between Target Dependencies and Compile Sources (drag it there).
# Install cocoapods: sudo gem install cocoapods
# Install pod dependencies: pod install (run in the samples/github/ios dir).
# Open the project/workspace: open github.xcworkspace
# Hit the 'run' button and it should work.

set -uxe
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ=github

FLETCH_DIR="$(cd "$DIR/../../.." && pwd)"
FLETCH_PKG_DIR="$FLETCH_DIR/package"
IMMI_GEN_DIR="$FLETCH_PKG_DIR/immi_gen"

TARGET_DIR="$(cd "$DIR/.." && pwd)"
TARGET_BUILD_DIR="$TARGET_DIR/build"
TARGET_PKG_DIR="$TARGET_BUILD_DIR/bin/packages"

mkdir -p $DIR/../generated
OUT_DIR="$(cd "$DIR/../generated" && pwd)"

DART="$FLETCH_DIR/out/ReleaseIA32/dart"

IMMIC="$DART $FLETCH_DIR/tools/immic/bin/immic.dart"
SERVICEC="$DART $FLETCH_DIR/tools/servicec/bin/servicec.dart"
FLETCHC="$DART -p $FLETCH_PKG_DIR $FLETCH_DIR/pkg/fletchc/lib/fletchc.dart"

# Generate dart node files with the pub transformer for immi.
(cd $TARGET_DIR && pub build bin -v --mode=debug)

# Generate dart service file and other immi files with the compiler.
# TODO(zerny): Rewrite the compilers to eliminate the 'global' immi_gen dir.
mkdir -p "$IMMI_GEN_DIR"
if [[ ! -L "$TARGET_PKG_DIR/immi_gen" ]]; then
    ln -s "$IMMI_GEN_DIR" "$TARGET_PKG_DIR/immi_gen"
fi

$IMMIC --package "$FLETCH_PKG_DIR" --out "$IMMI_GEN_DIR" "$TARGET_DIR/lib/$PROJ.immi"
$SERVICEC --out "$IMMI_GEN_DIR" "$IMMI_GEN_DIR/idl/immi_service.idl"

lipo -create -output "$DIR/libfletch.a" \
     "$FLETCH_DIR/out/ReleaseIA32/libfletch.a" \
     "$FLETCH_DIR/out/ReleaseXARM/libfletch.a"

exec $FLETCHC "$TARGET_BUILD_DIR/bin/$PROJ.dart" \
     --package-root="$TARGET_PKG_DIR" \
     --out "$OUT_DIR/$PROJ.snapshot"
