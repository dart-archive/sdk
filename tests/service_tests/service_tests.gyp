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
        'performance/performance_test.cc',
        'performance/cc/performance_service.cc',
        'performance/cc/performance_service.h',
        'performance/cc/struct.cc',
        'performance/cc/struct.h',
        'performance/cc/unicode.cc',
        'performance/cc/unicode.h',
      ],
    },
    {
      'target_name': 'service_conformance_test',
      'type': 'executable',
      'dependencies': [
        '../../src/vm/vm.gyp:fletch_vm',
      ],
      'sources': [
        'conformance/cc/conformance_service.cc',
        'conformance/cc/conformance_service.h',
        'conformance/cc/struct.cc',
        'conformance/cc/struct.h',
        'conformance/cc/unicode.cc',
        'conformance/cc/unicode.h',
        'conformance/conformance_test.cc',
        'conformance/conformance_test_shared.cc',
        'conformance/conformance_test_shared.h',
      ],
    },
  ],
}
