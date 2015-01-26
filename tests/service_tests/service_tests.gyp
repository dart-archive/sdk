# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'target_defaults': {
    'include_dirs': [
      '../../',
    ],
  },
  'targets': [
    {
      'target_name': 'echo_service_test',
      'type': 'executable',
      'dependencies': [
        '../../src/vm/vm.gyp:fletch_vm',
      ],
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'echo/echo.cc',
        'echo/echo_service.cc',
        'echo/echo_shared.cc',
      ],
    },
  ],
}
