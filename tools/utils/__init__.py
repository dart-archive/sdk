# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# This file contains a set of utilities functions used by other Python-based
# scripts. Most of these utitlities are imported from tools/utils.py in the
# Dart SDK.

import imp
import platform
import re
import os

imp.load_source(
  'utils.dart_utils',
  os.path.join(os.path.dirname(__file__), '../../../dart/tools/utils.py'))

def DartBinary():
  tools_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
  dart_binary_prefix = os.path.join(tools_dir, 'testing', 'bin')
  if IsWindows():
    return os.path.join(dart_binary_prefix, 'win', 'dart.exe')
  else:
    arch = GuessArchitecture()
    system = GuessOS()
    dart_binary = 'dart'
    os_path = system

    if arch == 'arm':
      dart_binary = 'dart-arm'
    elif arch == 'arm64':
      dart_binary = 'dart-arm64'
    elif arch == 'mips':
      dart_binary = 'dart-mips'

    if system == 'macos':
      os_path = 'mac'

    return os.path.join(dart_binary_prefix, os_path, dart_binary)

import dart_utils

dart_utils.DartBinary = DartBinary

from dart_utils import *
