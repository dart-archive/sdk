# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# This file contains a set of utilities functions used by other Python-based
# scripts. Most of these utilities are imported from tools/utils.py in the Dart
# SDK.

import imp
import os

imp.load_source(
  'utils.dart_utils',
  os.path.join(
      os.path.dirname(__file__), '../../third_party/dart/tools/utils.py'))

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

# Import 'dart_utils' to create a name for the library that we can patch up.
import dart_utils

# Replace the version of DartBinary in dart_utils with our version. This means
# that if a method in dart_utils calls DartBinary, it gets our version. In
# addition, our version is also exported.
dart_utils.DartBinary = DartBinary

# Replace DART_DIR to get the right cwd for git commands.
dart_utils.DART_DIR = os.path.abspath(os.path.join(__file__, '..', '..', '..'))

# Use the version file in the fletch repo.
dart_utils.VERSION_FILE = os.path.join(dart_utils.DART_DIR, 'tools', 'VERSION')

# Now that we have patched 'dart_utils', import it into our own scope. This
# also means that we export everything from that library.
from dart_utils import *
