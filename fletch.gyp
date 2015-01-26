# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
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
      ],
      'actions': [
        {
          'action_name': 'run_compiler_tests',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'compiler_run_tests'
            '<(EXECUTABLE_SUFFIX)',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/compiler_run_tests.pass',
          ],
          'action': [
            "bash", "-c",
            "<(_inputs) && LANG=POSIX date '+Test passed on %+' > <(_outputs)",
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
      ],
      'actions': [
        {
          'action_name': 'run_shared_tests',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'shared_run_tests'
            '<(EXECUTABLE_SUFFIX)',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/shared_run_tests.pass',
          ],
          'action': [
            "bash", "-c",
            "<(_inputs) && LANG=POSIX date '+Test passed on %+' > <(_outputs)",
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
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'vm_run_tests'
            '<(EXECUTABLE_SUFFIX)',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/vm_run_tests.pass',
          ],
          'action': [
            "bash", "-c",
            "<(_inputs) && LANG=POSIX date '+Test passed on %+' > <(_outputs)",
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
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)fletch<(EXECUTABLE_SUFFIX)',
            'tests/service_tests/echo/echo.dart',
          ],
          'outputs': [
            '<(INTERMEDIATE_DIR)/echo.snapshot',
          ],
          'action': [
            '<@(_inputs)', '--out=<(INTERMEDIATE_DIR)/echo.snapshot',
          ],
        },
        {
          'action_name': 'run_echo_service_test',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'echo_service_test'
            '<(EXECUTABLE_SUFFIX)',
            '<(INTERMEDIATE_DIR)/echo.snapshot',
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
  ],
}
