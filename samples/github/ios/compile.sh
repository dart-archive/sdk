#!/bin/bash

# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

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
FLETCH="$FLETCH_DIR/out/ReleaseIA32/fletch"

# TODO(zerny): Create a project specific package directory.
if [[ ! -d "$TARGET_PKG_DIR" ]]; then
    ln -s "$FLETCH_PKG_DIR" "$TARGET_PKG_DIR"
fi

# Generate dart service file and other immi files with the compiler.
mkdir -p "$IMMI_GEN_DIR"
$IMMIC --package "$FLETCH_PKG_DIR" --out "$IMMI_GEN_DIR" "$TARGET_DIR/lib/$PROJ.immi"

mkdir -p "$SERVICE_GEN_DIR"
$SERVICEC --out "$SERVICE_GEN_DIR" "$IMMI_GEN_DIR/idl/immi_service.idl"

cd $FLETCH_DIR
./tools/persistent_process_info.sh --kill
exec $FLETCH compile-and-run -o "$DIR/$PROJ.snapshot" \
     "$TARGET_BUILD_DIR/bin/$PROJ.dart"
