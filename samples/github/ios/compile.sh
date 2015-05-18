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
PKG_DIR="$FLETCH_DIR/package"
IMMI_GEN_DIR="$PKG_DIR/immi_gen"
IMMI_SAMPLES_DIR="$PKG_DIR/immi_samples"
IMMI_SAMPLES_OUT_DIR="$IMMI_SAMPLES_DIR/generated"
OUT_DIR="$(cd "$DIR/../generated" && pwd)"

DART="$FLETCH_DIR/out/ReleaseIA32/dart"

IMMIC="$DART $FLETCH_DIR/tools/immic/bin/immic.dart"
SERVICEC="$DART $FLETCH_DIR/tools/servicec/bin/servicec.dart"
FLETCHC="$DART -p $FLETCH_DIR/package $FLETCH_DIR/pkg/fletchc/lib/fletchc.dart"

mkdir -p "$IMMI_GEN_DIR"
$IMMIC --package "$PKG_DIR" --out "$IMMI_GEN_DIR" "$DIR/../github.immi"
$SERVICEC --out "$IMMI_GEN_DIR" "$IMMI_GEN_DIR/idl/immi_service.idl"

lipo -create -output "$DIR/libfletch.a" \
     "$FLETCH_DIR/out/ReleaseIA32/libfletch.a" \
     "$FLETCH_DIR/out/ReleaseXARM/libfletch.a"

cd $FLETCH_DIR;
exec $FLETCHC "$DIR/../$PROJ.dart" --out "$OUT_DIR/$PROJ.snapshot"
