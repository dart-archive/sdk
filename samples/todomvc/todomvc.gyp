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
      'target_name': 'todomvc_sample',
      'type': 'executable',
      'dependencies': [
        '../../src/vm/vm.gyp:fletch_vm',
      ],
      'sources': [
        'src/cc/struct.cc',	         # generated
        'src/cc/struct.h',	         # generated
        'src/cc/todomvc_presenter.cc',	 # should be generated
        'src/cc/todomvc_presenter.h',	 # should be generated
        'src/cc/todomvc_service.cc',     # generated
        'src/cc/todomvc_service.h',      # generated
        'src/todomvc.cc',
        'src/todomvc_shared.cc',
        'src/todomvc_shared.h',
      ],
    },
  ],
}
