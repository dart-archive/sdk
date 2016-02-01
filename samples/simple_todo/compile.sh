#!/bin/bash

# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

set -eu

THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$THIS_DIR/../.." && pwd)

TEST_PY="$ROOT_DIR/tools/test.py"

ARCH="ia32"
MODE="release"
TARGET=""
OUT=""

function print_help() {
  echo
  echo "This script can be run as:"
  echo "  compile.sh [<options>] <target>"
  echo
  echo "  where <options> are:"
  echo "    -a <arch> (eg, ia32, x64)"
  echo "    -m <mode> (eg, debug, release)"
  echo
  echo "  and <target> is one of:"
  echo "    cc   (run the C-based CLI)"
  echo "    java (run the Java-based CLI)"
}

function print_error() {
  echo "Error: $1"
  print_help
  exit 1
}

function build() {
  SUFFIX=service_tests/simple_todo_$1
  OUT="$ROOT_DIR/out/${MODE_CC}${ARCH_UC}/temporary_test_output/$SUFFIX"
  $TEST_PY -a $ARCH -m $MODE fletch_tests/$SUFFIX
  echo
  echo "Compilation and testing succeeded"
  echo "Compiled output in"
  echo "  $OUT"
}

while [[ $# > 1 ]]; do
  case "$1" in
    -a|--arch) ARCH="$2"; shift 2;;
    -m|--mode) MODE="$2"; shift 2;;
    *) echo "Unknown option $1"; exit 1;;
  esac
done

if [[ $# == 1 ]]; then
  TARGET="$1"
  shift
else
  print_error "unsupplied target"
fi

# lowercase and uppercase arch
ARCH=$(echo -n "$ARCH" | tr "[:upper:]" "[:lower:]")
ARCH_UC=$(echo -n "$ARCH" | tr "[:lower:]" "[:upper:]")

# lowercase and capitalized mode
MODE=$(echo -n "$MODE" | tr "[:upper:]" "[:lower:]")
MODE_CC=$(echo -n "${MODE:0:1}" | tr "[:lower:]" "[:upper:]"; echo "${MODE:1}")

case "$TARGET" in
  cc)
    build cc
    $OUT/simple_todo_sample $OUT/simple_todo.snapshot
    ;;
  java)
    if [[ "$ARCH" != "x64" ]]; then
      print_error "Target java requires using 64 bit by setting: -a x64"
    fi
    build java
    LD_LIBRARY_PATH=$OUT \
    java -d64 -ea -cp $OUT/simple_todo.jar -Djava.library.path=$OUT \
      SimpleTodo $OUT/simple_todo.snapshot
    ;;
  *)
    print_error "unknown target '$TARGET'"
    ;;
esac
