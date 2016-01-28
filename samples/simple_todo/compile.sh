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
}

function print_error() {
  echo "Error: $1"
  print_help
  exit 1
}

function build() {
  $TEST_PY -a $ARCH -m $MODE fletch_tests/service_tests/simple_todo
  echo
  echo "Compilation and testing succeeded"
  echo "Compiled output in"
  echo "  $OUT_DIR"
}

while [[ $# > 1 ]]; do
  case "$1" in
    -a|--arch) ARCH="$2"; shift 2;;
    -m|--mode) MODE="$2"; shift 2;;
    *) echo "Unknown option $1"; exit 1;;
  esac
done

OUT_DIR="$ROOT_DIR/out/${MODE^}${ARCH^^}/temporary_test_output/service_tests/simple_todo"

if [[ $# == 1 ]]; then
  TARGET="$1"
  shift
else
  print_error "unsupplied target"
fi

if [[ "$TARGET" == "cc" ]]; then
  build
  $OUT_DIR/simple_todo_sample $OUT_DIR/simple_todo.snapshot
else
  print_error "unknown target '$TARGET'"
fi
