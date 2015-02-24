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
        'cc/struct.cc',	         # generated
        'cc/struct.h',	         # generated
        'cc/todomvc_presenter.cc',	 # should be generated
        'cc/todomvc_presenter.h',	 # should be generated
        'cc/todomvc_service.cc',     # generated
        'cc/todomvc_service.h',      # generated
        'todomvc.cc',
        'todomvc_shared.cc',
        'todomvc_shared.h',
      ],
    },
  ],
}
