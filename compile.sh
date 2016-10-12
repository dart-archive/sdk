#!/bin/bash

DARTINO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LLVM_BIN=$DARTINO_ROOT/third_party/llvm/llvm-build/bin

if [ ! -f "$1" ]; then
  echo "Usage: $0 file.dart";
  exit 1;
fi

function run {
  echo "Running: $@"
  $@
  EXITCODE=$?
  if [ $EXITCODE -ne 0 ]; then
    echo "Nonzero exit code: $EXITCODE. Exiting now ..."
    exit $EXITCODE
  fi
}

set -e

SOURCE="$1"
BASENAME="$2"
SNAPSHOT="$BASENAME.snapshot"
EXECUTABLE="$BASENAME"

# Regenerate ninja files
run ninja

# Used for building the `llvm-codegen` tool.
# => This works only in 64-bit, since the llvm libraries we link against are
#    only available in 64-bit.
run ninja -C out/DebugX64

# Used for linking the generated llvm code with dartino runtime and a very small
# embedder.
run ninja -C out/ReleaseX64 llvm_embedder
run ninja -C out/DebugX64 llvm_embedder

run out/DebugX64/dartino export $SOURCE $SNAPSHOT
run out/DebugX64/llvm-codegen -Xcodegen-64 $SNAPSHOT $BASENAME.bc

# Make text representation of LLVM IR (for debugging)
run $LLVM_BIN/llvm-dis $BASENAME.bc -o $BASENAME.ll

# Compile LLVM IR to x86 asm code.
run $LLVM_BIN/llc -exception-model=dwarf -o $BASENAME.S $BASENAME.bc

#
run as $BASENAME.S -o $BASENAME.o
run objcopy  --globalize-symbol=__LLVM_StackMaps $BASENAME.o $BASENAME.o

# Link generated code together with dartino runtime and llvm embedder.
run g++ -m64 -o $EXECUTABLE -Lout/DebugX64 -Lout/DebugX64/obj/src/vm -lllvm_embedder -ldartino -ldl -lpthread $BASENAME.o
