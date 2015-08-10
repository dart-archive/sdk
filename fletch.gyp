# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'mac_asan_dylib': '<(PRODUCT_DIR)/libclang_rt.asan_osx_dynamic.dylib',
  },

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
        'copy_asan',
      ],
    },
    {
      # The actual snapshots used in these tests are generated at test time.
      # TODO(zerny): Compile these programs at test time and remove this target.
      'target_name': 'snapshot_tests',
      'type': 'none',
      'toolsets': ['target'],
      'dependencies': [
        'src/vm/vm.gyp:fletch-vm',
        'copy_dart#host',
        'tests/service_tests/service_tests.gyp:service_performance_test',
        'tests/service_tests/service_tests.gyp:service_conformance_test',
        'samples/todomvc/todomvc.gyp:todomvc_sample',
        'copy_asan',
      ],
    },
    {
      'target_name': 'copy_asan',
      'type': 'none',
      'conditions': [
        [ 'OS=="mac"', {
          'copies': [
            {
              # The asan dylib file sets its install name as
              # @executable_path/..., and by copying to PRODUCT_DIR, we avoid
              # having to set DYLD_LIBRARY_PATH.
              'destination': '<(PRODUCT_DIR)',
              'files': [
                'third_party/clang/mac/lib/clang/3.7.0/'
                'lib/darwin/libclang_rt.asan_osx_dynamic.dylib',
              ],
            },
          ],
        }, { # OS!="mac"
          'actions': [
            {
              'action_name': 'touch_asan_dylib',
              'inputs': [
              ],
              'outputs': [
                '<(mac_asan_dylib)',
              ],
              'action': [
                'touch', '<@(_outputs)'
              ],
            },
          ],
        }],
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
            'third_party/bin/<(OS)/dart',
          ],
        },
      ],
    },
  ],
}
