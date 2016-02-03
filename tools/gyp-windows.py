#!/usr/bin/env python
# Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import os
import sys

script_dir = os.path.dirname(os.path.realpath(__file__))
dartino_src = os.path.abspath(os.path.join(script_dir, os.pardir))

assert os.path.exists(os.path.join(dartino_src, 'third_party', 'gyp', 'pylib'))
sys.path.append(os.path.join(dartino_src, 'third_party', 'gyp', 'pylib'))
import gyp

sys.path.append(os.path.join(dartino_src, 'tools', 'vs_dependency'))
import vs_toolchain

vs2013_runtime_dll_dirs = vs_toolchain.SetEnvironmentAndGetRuntimeDllDirs()

gyp_rc = gyp.script_main()

# TODO(herhut): Make the below work for dartino once compilation works.
if vs2013_runtime_dll_dirs:
  x64_runtime, x86_runtime = vs2013_runtime_dll_dirs
  vs_toolchain.CopyVsRuntimeDlls(
    os.path.join(dartino_src, "out"),
    (x86_runtime, x64_runtime))

sys.exit(gyp_rc)

