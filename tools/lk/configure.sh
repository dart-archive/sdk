#!/bin/bash
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

set -e

LK_PROJECT=${LK_PROJECT-vexpress-a9-test}

config=build-$LK_PROJECT/config.h

# Build the config.h file required for the project.
( cd ../third_party/lk/ && make PROJECT=$LK_PROJECT $config )

config_path=../third_party/lk/$config

cpu=`sed -n 's/.*ARM_CPU_CORTEX_\([MA][0-9]\).*/\L\1/p' $config_path | head -n 1`

LK_CPU=cortex-$cpu

echo "LK project: $LK_PROJECT"
echo "LK cpu:     $LK_CPU"

GYP_DEFINES="LK_PROJECT=$LK_PROJECT LK_CPU=$LK_CPU" ninja
