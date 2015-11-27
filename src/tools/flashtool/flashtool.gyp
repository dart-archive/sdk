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
      'target_name': 'flashtool',
      'type': 'executable',
      'toolsets': ['target'],
      'dependencies': [
        '../../vm/vm.gyp:libfletch',
        '../../vm/vm.gyp:fletch_relocation_library',
      ],
      'sources': [
        'main.cc',
      ],
    },
  ],
}
