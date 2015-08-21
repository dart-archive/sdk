#!/bin/bash

# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Setup of an android project can be done in two ways: using ndk-build or using
# the experimental native code support in Android Studio 1.3. This script
# supports the latter. For an example of the former see
# samples/todomvc/android/compile.sh

# Build steps
#  - Run immic.
#  - Run servicec.
#  - Copy output files from immic and servicec to the jni and java directories.
#  - Build fletch library generators for target platforms (here ia32 and arm).
#  - Copy fletch source files into the projects jni directory.
#  - Generate a snapshot of your Dart program and add it to you resources dir.

# Android Studio Setup
#  - Setup native support
#    (see http://tools.android.com/tech-docs/new-build-system/gradle-experimental)
#  - Configure the fletch build
#    (see samples/github/android/GithubSample/app/build.gradle)

PROJ=github
ANDROID_PROJ=GithubSample

set -ue

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

FLETCH_DIR="$(cd "$DIR/../../.." && pwd)"
FLETCH_PKG_DIR="$FLETCH_DIR/package"

TARGET_DIR="$(cd "$DIR/.." && pwd)"
TARGET_BUILD_DIR="$TARGET_DIR"

# TODO(zerny): Create a project specific package directory.
TARGET_PKG_DIR=$FLETCH_PKG_DIR #"$TARGET_BUILD_DIR/packages"

IMMI_GEN_DIR="$TARGET_PKG_DIR/immi"
SERVICE_GEN_DIR="$TARGET_PKG_DIR/service"

JAVA_DIR=$DIR/GithubSample/app/src/main/java/fletch
JNI_DIR=$DIR/GithubSample/app/src/main/jni
JNI_ARM7_DIR=$DIR/GithubSample/app/src/arm7/jni
JNI_IA32_DIR=$DIR/GithubSample/app/src/x86/jni

DART="$FLETCH_DIR/out/ReleaseIA32/dart"
IMMIC="$DART $FLETCH_DIR/tools/immic/bin/immic.dart"
SERVICEC="$DART $FLETCH_DIR/tools/servicec/bin/servicec.dart"
FLETCH="$FLETCH_DIR/out/ReleaseIA32/fletch"

set -x

if [[ $# -eq 0 ]] || [[ "$1" == "immi" ]]; then
    # Generate dart service file and other immi files with the compiler.
    mkdir -p "$IMMI_GEN_DIR"
    $IMMIC --package "$FLETCH_PKG_DIR" --out "$IMMI_GEN_DIR" "$TARGET_DIR/lib/$PROJ.immi"

    mkdir -p "$SERVICE_GEN_DIR"
    $SERVICEC --out "$SERVICE_GEN_DIR" "$IMMI_GEN_DIR/idl/immi_service.idl"

    # Copy servicec generated wrappers.
    # TODO(zerny): Avoid copying by directly linking it from app/build.gradle
    mkdir -p $JNI_DIR
    cp $SERVICE_GEN_DIR/java/jni/*.cc $JNI_DIR/

    # Copy servicec generated structures.
    # TODO(zerny): Avoid copying by directly linking it from app/build.gradle
    mkdir -p $JAVA_DIR
    cp $SERVICE_GEN_DIR/java/fletch/*.java $JAVA_DIR/
fi

if [[ $# -eq 0 ]] || [[ "$1" == "fletch" ]]; then
    # Build the native interpreter src for arm and x86.
    MODE=Develop

    cd $FLETCH_DIR
    ninja
    ninja -C out/ReleaseIA32
    ninja -C out/${MODE}XARMAndroid fletch_vm_library_generator
    ninja -C out/${MODE}IA32 fletch_vm_library_generator
    mkdir -p $JNI_ARM7_DIR
    mkdir -p $JNI_IA32_DIR
    out/${MODE}XARMAndroid/fletch_vm_library_generator > $JNI_ARM7_DIR/generated.S
    out/${MODE}IA32/fletch_vm_library_generator > $JNI_IA32_DIR/generated.S

    SOURCES="\
	src/shared/assert.cc \
	src/shared/bytecodes.cc \
	src/shared/connection.cc \
	src/shared/flags.cc \
	src/shared/native_process_posix.cc \
	src/shared/native_socket_linux.cc \
	src/shared/native_socket_posix.cc \
	src/shared/platform_linux.cc \
	src/shared/platform_posix.cc \
	src/shared/utils.cc \
	src/vm/android_print_interceptor.cc \
	src/vm/debug_info.cc \
	src/vm/event_handler.cc \
	src/vm/event_handler_linux.cc \
	src/vm/ffi.cc \
	src/vm/ffi_linux.cc \
	src/vm/ffi_posix.cc \
	src/vm/fletch.cc \
	src/vm/fletch_api_impl.cc \
	src/vm/gc_thread.cc \
	src/vm/heap.cc \
	src/vm/heap_validator.cc \
	src/vm/immutable_heap.cc \
	src/vm/interpreter.cc \
	src/vm/intrinsics.cc \
	src/vm/lookup_cache.cc \
	src/vm/natives.cc \
	src/vm/object.cc \
	src/vm/object_list.cc \
	src/vm/object_map.cc \
	src/vm/object_memory.cc \
	src/vm/port.cc \
	src/vm/process.cc \
	src/vm/program.cc \
	src/vm/program_folder.cc \
	src/vm/scheduler.cc \
	src/vm/selector_row.cc \
	src/vm/service_api_impl.cc \
	src/vm/session.cc \
	src/vm/snapshot.cc \
	src/vm/stack_walker.cc \
	src/vm/storebuffer.cc \
	src/vm/thread_pool.cc \
	src/vm/thread_posix.cc \
	src/vm/unicode.cc \
	src/vm/weak_pointer.cc \
	third_party/double-conversion/src/bignum-dtoa.cc \
	third_party/double-conversion/src/bignum.cc \
	third_party/double-conversion/src/cached-powers.cc \
	third_party/double-conversion/src/diy-fp.cc \
	third_party/double-conversion/src/double-conversion.cc \
	third_party/double-conversion/src/fast-dtoa.cc \
	third_party/double-conversion/src/fixed-dtoa.cc \
	third_party/double-conversion/src/strtod.cc"

    # Copy fletch sources to the android project.
    # TODO(zerny): Avoid copying by directly linking it from app/build.gradle
    for f in $SOURCES; do
	src="$FLETCH_DIR/$f"
	dst="$JNI_DIR/$f"
	mkdir -p `dirname $dst`
	cp $src $dst
    done
fi

if [[ $# -eq 0 ]] || [[ "$1" == "snapshot" ]]; then
    cd $FLETCH_DIR
    # Kill the persistent process
    ./tools/persistent_process_info.sh --kill; : > .fletch

    SNAPSHOT="$DIR/$ANDROID_PROJ/app/src/main/res/raw/${PROJ}_snapshot"
    mkdir -p `dirname "$SNAPSHOT"`
    $FLETCH compile-and-run -o "$SNAPSHOT" "$TARGET_BUILD_DIR/bin/$PROJ.dart"
fi

set +x

if [[ $# -eq 1 ]]; then
    echo
    echo "Only ran task $1."
    echo "Possible tasks: immi, fletch, and snapshot"
    echo "If Fletch or any IMMI files changed re-run compile.sh without arguments."
fi
