#!/bin/bash
#
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.


######################## Variables #########################
COMPILE_SH_DIR=`cd $(dirname "${BASH_SOURCE[0]}") ; pwd`
FLETCH_DIR=${COMPILE_SH_DIR}/../..
OUT=${PWD}
FLETCH="$FLETCH_DIR/out/ReleaseX64/fletch"
SERVICEC="$FLETCH x-servicec"


########################## Clean ###########################
rm -rf dart cc java


############## Execute Service Compiler ####################
$SERVICEC file "simple_todo.idl" out "${OUT}"

