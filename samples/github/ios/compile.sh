#!/bin/bash

# Setup
#  - Install and build fletch.
#  - Install Cocoapods.
#  - Run immic (output in packages/immi).
#  - Run servicec (output in packages/service).
#  - Generate libfletch.a for your choice of platforms and add it to xcode.
#  - Generate snapshot of your Dart program and add it to xcode.
#  - Write Podfile that links to {Fletch,Service,Immi}.podspec.
#  - Run pod install.

# Build (implemented by the present script).
#  - Run immic.
#  - Run servicec.
#  - Generate snapshot of your Dart program.
#  - Hit the 'run' button in xcode.

# To run the above as part of xcode 'run'
# Open your <proj>.xcodeproj (not the xcworkspace)
# and add a "Run Script" with content ./compile.sh in Build Phases and place it
# between Target Dependencies and Compile Sources (drag it there).

set -uxe
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ=github

FLETCH_DIR="$(cd "$DIR/../../.." && pwd)"
FLETCH_PKG_DIR="$FLETCH_DIR/package"

TARGET_DIR="$(cd "$DIR/.." && pwd)"
TARGET_BUILD_DIR="$TARGET_DIR"
TARGET_PKG_DIR="$TARGET_BUILD_DIR/packages"

IMMI_GEN_DIR="$TARGET_PKG_DIR/immi"
SERVICE_GEN_DIR="$TARGET_PKG_DIR/service"

DART="$FLETCH_DIR/out/ReleaseIA32/dart"
IMMIC="$DART $FLETCH_DIR/tools/immic/bin/immic.dart"
SERVICEC="$DART $FLETCH_DIR/tools/servicec/bin/servicec.dart"
FLETCHC="$DART -p $FLETCH_PKG_DIR $FLETCH_DIR/pkg/fletchc/lib/fletchc.dart"

# TODO(zerny): Create a project specific package directory.
if [[ ! -d "$TARGET_PKG_DIR" ]]; then
    ln -s "$FLETCH_PKG_DIR" "$TARGET_PKG_DIR"
fi

# Generate dart service file and other immi files with the compiler.
mkdir -p "$IMMI_GEN_DIR"
$IMMIC --package "$FLETCH_PKG_DIR" --out "$IMMI_GEN_DIR" "$TARGET_DIR/lib/$PROJ.immi"

mkdir -p "$SERVICE_GEN_DIR"
$SERVICEC --out "$SERVICE_GEN_DIR" "$IMMI_GEN_DIR/idl/immi_service.idl"

exec $FLETCHC "$TARGET_BUILD_DIR/bin/$PROJ.dart" \
     --package-root="$TARGET_PKG_DIR" \
     --out "$DIR/$PROJ.snapshot"
