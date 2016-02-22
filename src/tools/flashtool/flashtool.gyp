# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
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
      'target_name': 'flashtool',
      'type': 'executable',
      'toolsets': ['host'],
      'dependencies': [
        '../../vm/vm.gyp:dartino_vm_runtime_library',
        '../../vm/vm.gyp:dartino_relocation_library',
      ],
      'sources': [
        'main.cc',
      ],
    },
  ],
}
