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
      'target_name': 'service_performance_test',
      'type': 'executable',
      'dependencies': [
        '../../src/vm/vm.gyp:fletch_vm',
      ],
      'sources': [
        'performance/echo.cc',
        'performance/echo_shared.cc',
        'performance/echo_shared.h',
        'performance/cc/echo_service.cc',
        'performance/cc/echo_service.h',
      ],
    },
    {
      'target_name': 'service_conformance_test',
      'type': 'executable',
      'dependencies': [
        '../../src/vm/vm.gyp:fletch_vm',
      ],
      'sources': [
        'conformance/cc/person_counter.cc',
        'conformance/cc/person_counter.h',
        'conformance/cc/struct.cc',
        'conformance/cc/struct.h',
        'conformance/person.cc',
        'conformance/person_shared.cc',
        'conformance/person_shared.h',
      ],
    },
  ],
}
