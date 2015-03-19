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
      'target_name': 'fletch_driver',
      'type': 'executable',
      'toolsets': ['host'],
      'dependencies': [
        '../../shared/shared.gyp:fletch_shared',
      ],
      'sources': [
        'main.cc',

        'connection.h',
        'connection.cc',
        'get_path_of_executable.h',
        'get_path_of_executable_linux.cc',
        'get_path_of_executable_macos.cc',
      ],
    },
  ],
}
