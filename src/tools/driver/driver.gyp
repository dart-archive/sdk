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
        'FLETCHC_LIBRARY_ROOT="../../../dart/sdk"',
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
        # TODO(ricow): Fill in the correct path.
        'FLETCHC_LIBRARY_ROOT="../TO BE FILLED IN"',
      ],
      'sources': [
        'main.cc',
      ],
    },
  ],
}
