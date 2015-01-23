# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
    {
      'target_name': 'compiler',
      'type': 'none',
      'dependencies': [
        'src/compiler/compiler.gyp:fletch_compiler',
        'src/shared/shared.gyp:fletch_shared',
        'src/vm/vm.gyp:fletch_vm',
        'src/vm/vm.gyp:fletch_vm_generator',
      ],
    },
  ],
}
