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
      'target_name': 'fletch',
      'type': 'executable',
      'toolsets': ['host'],
      'dependencies': [
        '../../shared/shared.gyp:fletch_shared',
      ],
      'sources': [
        'main.cc',

        'connection.cc',
        'connection.h',
        'platform.h',
        'platform_linux.cc',
        'platform_macos.cc',
      ],
    },
  ],
}
