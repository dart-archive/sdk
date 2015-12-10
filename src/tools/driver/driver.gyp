# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
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
        '../../shared/shared.gyp:fletch_shared',
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
      'target_name': 'fletch',
      'type': 'executable',
      'toolsets': ['target'],
      'dependencies': [
        'driver',
      ],
      'defines': [
        'FLETCHC_LIBRARY_ROOT="../../lib"',
        # How many directories up is the root, used for getting full path to
        # the .packages file for the compiler
        'FLETCH_ROOT_DISTANCE=2',
        'FLETCHC_PKG_FILE="pkg/fletchc/.packages"',
        'DART_VM_NAME="dart"',
      ],
      'sources': [
        'main.cc',
      ],
    },
    # The same as fletch, but with paths relative to the location in
    # the sdk.
    {
      'target_name': 'fletch_for_sdk',
      'type': 'executable',
      'toolsets': ['target'],
      'dependencies': [
        'driver',
      ],
      'defines': [
        'FLETCHC_LIBRARY_ROOT="../internal/fletch_lib"',
        # How many directories up is the root, used for getting full path to
        # the .packages file for the compiler
        'FLETCH_ROOT_DISTANCE=1',
        'FLETCHC_PKG_FILE="internal/pkg/fletchc/.packages"',
        'DART_VM_NAME="../internal/dart"',
      ],
      'sources': [
        'main.cc',
      ],
    },
  ],
}
