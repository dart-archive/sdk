#!/bin/bash

DARTINO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LLVM_BIN=$DARTINO_ROOT/third_party/llvm/llvm-build-release/bin

ARCH=IA32
COMPILER=g++
COMPILER_ARG=-m32
LLVM_ARCH=x86
LLC_ARG=

if [ ! -f "$1" ]; then
  echo "Usage: $0 file.snapshot";
  exit 1;
fi

if [ "$2" = "arm" ]; then
  ARCH="XARM"
  COMPILER="arm-linux-gnueabihf-g++"
  COMPILER_ARG=""
  LLVM_ARCH="arm"
  echo "Using XARM for building"
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
run ninja -C out/Release$ARCH llvm_embedder
run ninja -C out/Debug$ARCH llvm_embedder

run rm -f $EXECUTABLE
run rm -f $BASENAME.bc $BASENAME.ll $BASENAME.S $BASENAME.o
run rm -f ${BASENAME}_opt.bc ${BASENAME}_opt.ll ${BASENAME}_opt.S ${BASENAME}_opt.o

run out/DebugX64/llvm-codegen $SNAPSHOT $BASENAME.bc

# Make an optimized version of the bitcode
run $LLVM_BIN/opt -O3 $BASENAME.bc -o ${BASENAME}_opt.bc

# Make text representation of LLVM IR (for debugging)
run $LLVM_BIN/llvm-dis $BASENAME.bc -o $BASENAME.ll
run $LLVM_BIN/llvm-dis ${BASENAME}_opt.bc -o ${BASENAME}_opt.ll

# Compile LLVM IR to 32-bit x86 asm code.
run $LLVM_BIN/llc -march=$LLVM_ARCH -o $BASENAME.S $BASENAME.bc
run $LLVM_BIN/llc -march=$LLVM_ARCH -o ${BASENAME}_opt.S ${BASENAME}_opt.bc

# Don't know why, but llc's emitted .S file contains some floating point ABI
# annotation which the linker doesn't like.
sed -i 's/^\(.*Tag_ABI_FP_number_model\)$/@\1/g' ${BASENAME}_opt.S
sed -i 's/^\(.*Tag_ABI_FP_number_model\)$/@\1/g' ${BASENAME}.S

# Link generated code together with dartino runtime and llvm embedder.
run $COMPILER $COMPILER_ARG -o $BASENAME -Lout/Release$ARCH -Lout/Release$ARCH/obj/src/vm -lllvm_embedder -ldartino -ldl -lpthread $BASENAME.S
run $COMPILER $COMPILER_ARG -o ${BASENAME}_opt -Lout/Release$ARCH -Lout/Release$ARCH/obj/src/vm -lllvm_embedder -ldartino -ldl -lpthread ${BASENAME}_opt.S

