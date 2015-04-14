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
      'target_name': 'myapi_test',
      'type': 'executable',
      'dependencies': [
        '../../src/vm/vm.gyp:fletch_vm',
      ],
      'sources': [
        'myapi_client.cc',
        'generated/myapi.h',
        'generated/cc/myapi_service.cc',
        'generated/cc/myapi_service.h',
        'generated/cc/struct.cc',
        'generated/cc/struct.h',
        'generated/cc/unicode.cc',
        'generated/cc/unicode.h',
      ],
    },
  ],
}
