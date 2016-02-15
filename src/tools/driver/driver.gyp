# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'target_defaults': {
    'include_dirs': [
      '../../../',
    ],
  },
  'targets': [
    {
      'target_name': 'driver',
      'type': 'static_library',
      'toolsets': ['target'],
      'dependencies': [
        '../../shared/shared.gyp:dartino_shared',
      ],
      'sources': [
        'connection.cc',
        'connection.h',
        'platform.h',
        'platform_linux.cc',
        'platform_macos.cc',
      ],
    },
    {
      'target_name': 'dartino',
      'type': 'executable',
      'toolsets': ['target'],
      'dependencies': [
        'driver',
	# The natives mapping is required by the compiler dartino relies on.
        '../../shared/shared.gyp:natives_json',
	# We need a dartino-vm to talk to.
        '../../vm/vm.gyp:dartino-vm',
      ],
      'defines': [
        'DARTINOC_LIBRARY_ROOT="../../lib"',
        # How many directories up is the root, used for getting full path to
        # the .packages file for the compiler
        'DARTINO_ROOT_DISTANCE=2',
        'DARTINOC_PKG_FILE="pkg/dartino_compiler/.packages"',
        'DART_VM_NAME="dart"',
      ],
      'sources': [
        'main.cc',
      ],
    },
    # The same as dartino, but with paths relative to the location in
    # the sdk.
    {
      'target_name': 'dartino_for_sdk',
      'type': 'executable',
      'toolsets': ['target'],
      'dependencies': [
        'driver',
      ],
      'defines': [
        'DARTINOC_LIBRARY_ROOT="../internal/dartino_lib"',
        # How many directories up is the root, used for getting full path to
        # the .packages file for the compiler
        'DARTINO_ROOT_DISTANCE=1',
        'DARTINOC_PKG_FILE="internal/pkg/dartino_compiler/.packages"',
        'DART_VM_NAME="../internal/dart"',
      ],
      'sources': [
        'main.cc',
      ],
    },
  ],
}
