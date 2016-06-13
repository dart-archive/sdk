# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
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
      'target_name': 'freertos_dartino_host_cc_tests',
      'type': 'executable',
      'dependencies': [
        '../vm/vm.gyp:libdartino',
        '../shared/shared.gyp:cc_test_base',
      ],
      'defines': [
        'TESTING',
      ],
      'sources': [
        'circular_buffer.cc',
        'circular_buffer_test.cc',
      ],
    },
  ],
}
