# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
    {
      'target_name': 'fletch-vm',
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:fletch-vm',
      ],
    },
    {
      'target_name': 'c_test_library',
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:ffi_test_library',
      ],
    },
    {
      'target_name': 'natives_json',
      'type': 'none',
      'toolsets': ['host'],
      'dependencies': [
        'src/shared/shared.gyp:natives_json',
      ],
    },
    {
      'target_name': 'toplevel_fletch',
      'type': 'none',
      'toolsets': ['target'],
      'dependencies': [
        'src/tools/driver/driver.gyp:fletch',
        'copy_dart#host',
      ],
    },
    {
      # C based test executables. See also tests/cc_tests/README.md.
      'target_name': 'cc_tests',
      'type': 'none',
      'toolsets': ['target'],
      'dependencies': [
        'src/shared/shared.gyp:shared_cc_tests',
        'src/vm/vm.gyp:vm_cc_tests',
      ],
    },
    {
      'target_name': 'copy_dart',
      'type': 'none',
      'toolsets': ['host'],
      'copies': [
        {
          'destination': '<(PRODUCT_DIR)',
          'files': [
            'third_party/bin/<(OS)/dart<(EXECUTABLE_SUFFIX)',
          ],
        },
      ],
    },
  ],
}
