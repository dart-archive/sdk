# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'mac_asan_dylib': '<(PRODUCT_DIR)/libclang_rt.asan_osx_dynamic.dylib',
  },

  # SCons translation:
  # compiler/libfletch.a is now src/compiler/compiler.gyp:fletch_compiler.
  # lib/libfletch.a is now src/vm/vm.gyp:fletch_vm.
  # shared/libshared.a is now src/shared/shared.gyp:fletch_shared.
  # TODO(ahe): Remove the above lines when SCons is gone.
  'targets': [
    {
      'target_name': 'fletch',
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:fletch',
      ],
    },
    {
      'target_name': 'fletchc',
      'type': 'none',
      'dependencies': [
        'src/compiler/compiler.gyp:fletchc',
      ],
    },
    {
      'target_name': 'fletchc_scan',
      'type': 'none',
      'dependencies': [
        'src/compiler/compiler.gyp:fletchc_scan',
      ],
    },
    {
      'target_name': 'bench',
      'type': 'none',
      'dependencies': [
        'src/compiler/compiler.gyp:bench',
      ],
    },
    {
      'target_name': 'fletchc_print',
      'type': 'none',
      'dependencies': [
        'src/compiler/compiler.gyp:fletchc_print',
      ],
    },
    {
      'target_name': 'run_compiler_tests',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/compiler/compiler.gyp:compiler_run_tests',
        'copy_asan',
      ],
      'actions': [
        {
          'action_name': 'run_compiler_tests',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'compiler_run_tests'
            '<(EXECUTABLE_SUFFIX)',
          ],
          'inputs': [
            '<@(_command)',
            '<(mac_asan_dylib)',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/compiler_run_tests.pass',
          ],
          'action': [
            "bash", "-c",
            "<(_command) && LANG=POSIX date '+Test passed on %+' > <(_outputs)",
          ],
        },
      ],
    },
    {
      'target_name': 'run_shared_tests',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/shared/shared.gyp:shared_run_tests',
        'copy_asan',
      ],
      'actions': [
        {
          'action_name': 'run_shared_tests',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'shared_run_tests'
            '<(EXECUTABLE_SUFFIX)',
          ],
          'inputs': [
            '<@(_command)',
            '<(mac_asan_dylib)',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/shared_run_tests.pass',
          ],
          'action': [
            "bash", "-c",
            "<(_command) && LANG=POSIX date '+Test passed on %+' > <(_outputs)",
          ],
        },
      ],
    },
    {
      'target_name': 'run_vm_tests',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:vm_run_tests',
      ],
      'actions': [
        {
          'action_name': 'run_vm_tests',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'vm_run_tests'
            '<(EXECUTABLE_SUFFIX)',
          ],
          'inputs': [
            '<@(_command)',
            '<(mac_asan_dylib)',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/vm_run_tests.pass',
          ],
          'action': [
            "bash", "-c",
            "<(_command) && LANG=POSIX date '+Test passed on %+' > <(_outputs)",
          ],
        },
      ],
    },
    {
      'target_name': 'run_echo_service_test',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:fletch',
        'tests/service_tests/service_tests.gyp:echo_service_test',
      ],
      'actions': [
        {
          'action_name': 'generate_echo_snapshot',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)fletch<(EXECUTABLE_SUFFIX)',
            'tests/service_tests/echo/echo.dart',
          ],
          'inputs': [
            '<@(_command)',
            '<(mac_asan_dylib)',
          ],
          'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/echo.snapshot',
          ],
          'action': [
            '<@(_command)', '--out=<(SHARED_INTERMEDIATE_DIR)/echo.snapshot',
          ],
        },
        {
          'action_name': 'run_echo_service_test',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'echo_service_test'
            '<(EXECUTABLE_SUFFIX)',
            '<(SHARED_INTERMEDIATE_DIR)/echo.snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/echo_service_test.pass',
          ],
          'action': [
            "bash", "-c",
            "<(_inputs) && LANG=POSIX date '+Test passed on %+' > "
            "<(_outputs)",
          ],
        },
      ],
    },
    {
      'target_name': 'run_person_service_test',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:fletch',
        'tests/service_tests/service_tests.gyp:person_service_test',
      ],
      'actions': [
        {
          'action_name': 'generate_person_snapshot',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)fletch<(EXECUTABLE_SUFFIX)',
            'tests/service_tests/person/person.dart',
          ],
          'inputs': [
            '<@(_command)',
            '<(mac_asan_dylib)',
          ],
          'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/person.snapshot',
          ],
          'action': [
            '<@(_command)', '--out=<(SHARED_INTERMEDIATE_DIR)/person.snapshot',
          ],
        },
        {
          'action_name': 'run_person_service_test',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'person_service_test'
            '<(EXECUTABLE_SUFFIX)',
            '<(SHARED_INTERMEDIATE_DIR)/person.snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/person_service_test.pass',
          ],
          'action': [
            "bash", "-c",
            "<(_inputs) && LANG=POSIX date '+Test passed on %+' > "
            "<(_outputs)",
          ],
        },
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
                'third_party/clang/mac/lib/clang/3.6.0/'
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
  ],
  'conditions': [
    [ 'OS == "mac"', {
       'targets': [
          {
            'target_name': 'run_objc_echo_service_test',
            # Note: this target_name needs to be different from its dependency.
            # This is due to the ninja GYP generator which doesn't generate
            # unique names.
            'type': 'none',
            'dependencies': [
              'run_echo_service_test', # For snapshot generation.
              'src/vm/vm.gyp:fletch',
              'tests/service_tests/service_tests.gyp:objc_echo_service_test',
            ],
            'actions': [
              {
                'action_name': 'run_objc_echo_service_test',
                'inputs': [
                  '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
                  'objc_echo_service_test'
                  '<(EXECUTABLE_SUFFIX)',
                  '<(SHARED_INTERMEDIATE_DIR)/echo.snapshot',
                ],
                'outputs': [
                  '<(PRODUCT_DIR)/test_outcomes/objc_echo_service_test.pass',
                ],
                'action': [
                  "bash", "-c",
                  "<(_inputs) && LANG=POSIX date '+Test passed on %+' > "
                  "<(_outputs)",
                ],
              },
            ],
          },
       ],
    }],
  ],
}
