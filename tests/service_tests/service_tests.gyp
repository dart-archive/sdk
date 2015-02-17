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
        'echo/echo.cc',
        'echo/echo_shared.cc',
        'echo/echo_shared.h',
        'echo/cc/echo_service.cc',
        'echo/cc/echo_service.h',
      ],
    },
    {
      'target_name': 'person_service_test',
      'type': 'executable',
      'dependencies': [
        '../../src/vm/vm.gyp:fletch_vm',
      ],
      'sources': [
        'person/cc/person_counter.cc',
        'person/cc/person_counter.h',
        'person/cc/struct.cc',
        'person/cc/struct.h',
        'person/person.cc',
        'person/person_shared.cc',
        'person/person_shared.h',
      ],
    },
  ],
}
