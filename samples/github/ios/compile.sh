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
#  - Generate libfletch.
#  - Generate snapshot of your Dart program.

# After this, hit the 'run' button in xcode.

set -ue
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

MOCK_SERVER_SNAPSHOT="$TARGET_DIR/github_mock_service.snapshot"

set -x

# TODO(zerny): Create a project specific package directory.
if [[ ! -d "$TARGET_PKG_DIR" ]]; then
    ln -s "$FLETCH_PKG_DIR" "$TARGET_PKG_DIR"
fi

# Generate dart service file and other immi files with the compiler.
if [[ $# -eq 0 ]] || [[ "$1" == "immi" ]]; then
    rm -rf "$IMMI_GEN_DIR"
    mkdir -p "$IMMI_GEN_DIR"
    $IMMIC --package "$FLETCH_PKG_DIR" --out "$IMMI_GEN_DIR" "$TARGET_DIR/lib/$PROJ.immi"

    rm -rf "$SERVICE_GEN_DIR"
    mkdir -p "$SERVICE_GEN_DIR"
    $SERVICEC --out "$SERVICE_GEN_DIR" "$IMMI_GEN_DIR/idl/immi_service.idl"

    # Regenerate the mock service after deleting the service-gen directory.
    $DIR/../compile_mock_service.sh service
fi

if [[ $# -eq 0 ]] || [[ "$1" == "fletch" ]]; then
    cd $FLETCH_DIR
    ninja -C out/ReleaseIA32
    ninja -C out/ReleaseXARM libfletch
    lipo -create -output "$DIR/libfletch.a" \
         out/ReleaseIA32/libfletch.a \
         out/ReleaseXARM/libfletch.a
fi

if [[ $# -eq 0 ]] || [[ "$1" == "snapshot" ]]; then
    cd $FLETCH_DIR
    ninja -C out/ReleaseIA32
    ./tools/persistent_process_info.sh --kill
    $FLETCH compile-and-run -o "$DIR/$PROJ.snapshot" \
            "$TARGET_BUILD_DIR/bin/$PROJ.dart"
fi
    
# Ensure that we have a mock server.
if [[ $# -eq 0 ]] && [[ ! -f "$MOCK_SERVER_SNAPSHOT" ]]; then
    $DIR/../compile_mock_service.sh
fi

set +x

if [[ $# -eq 1 ]]; then
    echo
    echo "Only ran task $1."
    echo "Possible tasks: immi, fletch, and snapshot"
    echo "If Fletch or any IMMI files changed re-run compile.sh without arguments."
fi
