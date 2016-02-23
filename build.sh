#!/bin/bash

if [ ! -f "$1" ]; then
  echo "Usage: $0 file.snapshot";
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

SNAPSHOT="$1"
BASENAME=${SNAPSHOT%.*}
EXECUTABLE=$BASENAME

# Regenerate ninja files
run ninja

# Used for building the `llvm-codegen` tool.
# => This works only in 64-bit, since the llvm libraries we link against are
#    only available in 64-bit.
run ninja -C out/DebugX64

# Used for linking the generated llvm code with dartino runtime and a very small
# embedder.
run ninja -C out/DebugIA32 llvm_embedder

run rm -f $EXECUTABLE
run rm -f $BASENAME.bc $BASENAME.ll $BASENAME.S $BASENAME.o

run out/DebugX64/llvm-codegen $SNAPSHOT $BASENAME.bc

# Make text representation of LLVM IR (for debugging)
run llvm-dis $BASENAME.bc -o $BASENAME.ll

# Compile LLVM IR to 32-bit x86 asm code.
run llc -march=x86 -o $BASENAME.S $BASENAME.bc

# Link generated code together with dartino runtime and llvm embedder.
run g++ -m32 -o $BASENAME -Lout/DebugIA32 -Lout/DebugIA32/obj/src/vm -lllvm_embedder -ldartino -ldl -lpthread $BASENAME.S

