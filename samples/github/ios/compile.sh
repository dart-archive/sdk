#!/bin/bash

# Manual setup in xcode.
# Add $(PROJECT_DIR)/../../.. to Build Settings / Header Search Path
# Add $(PROJECT_DIR)/../generated to Build Settings / User Header Search Path
# Add out/ReleaseXARM/libfletch.a to Build Phases / Link Binary with Libraries
# Set 'no' in Build Settings / Dead Code Stripping
# Add directory reference for /generated
# Add a "Run Script" with content ./compile.sh in Build Phases
# and place it between Target Dependencies and Compile Sources (drag it there).

set -uxe
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ=github

FLETCH_DIR="$DIR/../../.."
OUT_DIR="$DIR/../generated"

DART="$FLETCH_DIR/out/ReleaseIA32/dart"

IMMIC="$DART $FLETCH_DIR/tools/immic/bin/immic.dart"
SERVICEC="$DART $FLETCH_DIR/tools/servicec/bin/servicec.dart"
FLETCHC="$DART -p $FLETCH_DIR/package $FLETCH_DIR/pkg/fletchc/lib/fletchc.dart"

$IMMIC --out "$OUT_DIR" "$DIR/../github.immi"
$SERVICEC --out "$OUT_DIR" "$OUT_DIR/idl/${PROJ}_presenter_service.idl"

lipo -create -output "$DIR/libfletch.a" \
     "$FLETCH_DIR/out/ReleaseIA32/libfletch.a" \
     "$FLETCH_DIR/out/ReleaseXARM/libfletch.a"

cd $FLETCH_DIR;
exec $FLETCHC "$DIR/../$PROJ.dart" --out "$DIR/../generated/$PROJ.snapshot"
