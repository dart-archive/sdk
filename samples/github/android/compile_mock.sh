#!/bin/bash

# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Build steps
#  - Run servicec.
#  - Build fletch library generators for target platforms (here ia32 and arm).
#  - In the servicec java output directory build libfletch using ndk-build.
#  - Copy/link output files servicec to the jni and java directories.
#  - Generate a snapshot of your Dart program and add it to you resources dir.

PROJ=github
ANDROID_PROJ=GithubMock
DART_FILE=bin/github_mock_service.dart

set -ue

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

FLETCH_DIR="$(cd "$DIR/../../.." && pwd)"

# TODO(zerny): Support other modes than Release in tools/android_build/jni/Android.mk
TARGET_MODE=Release
TARGET_DIR="$(cd "$DIR/.." && pwd)"
TARGET_GEN_DIR="$TARGET_DIR/generated"
TARGET_PKG_FILE="$TARGET_DIR/.packages"

SERVICE_GEN_DIR="$TARGET_GEN_DIR/service"

JAVA_DIR=$DIR/$ANDROID_PROJ/app/src/main/java/fletch
JNI_LIBS_DIR=$DIR/$ANDROID_PROJ/app/src/main/jniLibs

MOCK_SERVER_SNAPSHOT="$TARGET_DIR/github_mock_service.snapshot"

set -x

# Compile dart service file.
if [[ $# -eq 0 ]] || [[ "$1" == "service" ]]; then
    rm -rf "$SERVICE_GEN_DIR"
    $DIR/../compile_mock_service.sh service

    # TODO(zerny): Change the servicec output directory structure to allow easy
    # referencing from Android Studio.
    mkdir -p $JAVA_DIR
    cp -R $SERVICE_GEN_DIR/java/fletch/*.java $JAVA_DIR/
fi

# Build the native interpreter src for arm and x86.
if [[ $# -eq 0 ]] || [[ "$1" == "fletch" ]]; then
    cd $FLETCH_DIR
    ninja
    ninja -C out/${TARGET_MODE}XARMAndroid fletch_vm_library_generator
    ninja -C out/${TARGET_MODE}IA32Android fletch_vm_library_generator
    mkdir -p out/${TARGET_MODE}XARMAndroid/obj/src/vm/fletch_vm.gen
    mkdir -p out/${TARGET_MODE}IA32Android/obj/src/vm/fletch_vm.gen
    out/${TARGET_MODE}XARMAndroid/fletch_vm_library_generator > \
        out/${TARGET_MODE}XARMAndroid/obj/src/vm/fletch_vm.gen/generated.S
    out/${TARGET_MODE}IA32Android/fletch_vm_library_generator > \
        out/${TARGET_MODE}IA32Android/obj/src/vm/fletch_vm.gen/generated.S

    cd $SERVICE_GEN_DIR/java
    CPUCOUNT=1
    if [[ $(uname) = 'Darwin' ]]; then
        CPUCOUNT=$(sysctl -n hw.logicalcpu_max)
    else
        CPUCOUNT=$(lscpu -p | grep -vc '^#')
    fi
    NDK_MODULE_PATH=. ndk-build -j$CPUCOUNT

    mkdir -p $JNI_LIBS_DIR
    cp -R libs/* $JNI_LIBS_DIR/
fi

# TODO(zerny): should this always recompile the mock data and snapshot?
if [[ $# -eq 0 ]] && [[ ! -f "$MOCK_SERVER_SNAPSHOT" ]]; then
    $DIR/../compile_mock_service.sh
fi

if [[ $# -eq 0 ]] || [[ "$1" == "snapshot" ]]; then
    SNAPSHOT="$DIR/$ANDROID_PROJ/app/src/main/res/raw/snapshot"
    mkdir -p `dirname "$SNAPSHOT"`
    cp "$MOCK_SERVER_SNAPSHOT" "$SNAPSHOT"
fi

set +x

if [[ $# -eq 1 ]]; then
    echo
    echo "Only ran task $1."
    echo "Possible tasks: service, fletch, and snapshot"
    echo "If Fletch or any IMMI files changed re-run compile.sh without arguments."
fi
