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
      'target_name': 'natives_json',
      'type': 'none',
      'toolsets': ['host'],
      'dependencies': [
        'src/shared/shared.gyp:natives_json',
      ],
    },
    {
      'target_name': 'fletch_driver',
      'type': 'none',
      'toolsets': ['host'],
      'dependencies': [
        'src/tools/driver/driver.gyp:fletch_driver',
        'copy_dart',
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
        'copy_asan',
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
      'target_name': 'run_service_performance_test',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:fletch',
        'copy_dart#host',
        'tests/service_tests/service_tests.gyp:service_performance_test',
        'copy_asan',
      ],
      'actions': [
        {
          'action_name': 'generate_service_performance_snapshot',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)dart<(EXECUTABLE_SUFFIX)',
            '-p',
            '<(PRODUCT_DIR)/../../package/',
            '<(PRODUCT_DIR)/../../pkg/fletchc/lib/fletchc.dart',
            'tests/service_tests/performance/performance_service_impl.dart',
          ],
          'inputs': [
            '<(mac_asan_dylib)',
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'dart'
            '<(EXECUTABLE_SUFFIX)',
            # TODO(ahe): Also depend on .dart files in the core libraries.
            'tests/service_tests/performance/dart/performance_service.dart',
            'tests/service_tests/performance/dart/struct.dart',
          ],
          'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/service_performance.snapshot',
          ],
          'action': [
            '<@(_command)',
            '--out',
            '<(SHARED_INTERMEDIATE_DIR)/service_performance.snapshot',
          ],
        },
        {
          'action_name': 'run_service_performance_test',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'service_performance_test'
            '<(EXECUTABLE_SUFFIX)',
            '<(SHARED_INTERMEDIATE_DIR)/service_performance.snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/service_performance_test.pass',
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
      'target_name': 'run_service_conformance_test',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:fletch',
        'copy_dart#host',
        'tests/service_tests/service_tests.gyp:service_conformance_test',
        'copy_asan',
      ],
      'actions': [
        {
          'action_name': 'generate_service_conformance_snapshot',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)dart<(EXECUTABLE_SUFFIX)',
            '-p',
            '<(PRODUCT_DIR)/../../package/',
            '<(PRODUCT_DIR)/../../pkg/fletchc/lib/fletchc.dart',
            'tests/service_tests/conformance/conformance_service_impl.dart',
          ],
          'inputs': [
            '<(mac_asan_dylib)',
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'dart'
            '<(EXECUTABLE_SUFFIX)',
            # TODO(ahe): Also depend on .dart files in the core libraries.
            'tests/service_tests/conformance/dart/conformance_service.dart',
            'tests/service_tests/conformance/dart/struct.dart',
          ],
          'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/service_conformance.snapshot',
          ],
          'action': [
            '<@(_command)',
            '--out',
            '<(SHARED_INTERMEDIATE_DIR)/service_conformance.snapshot',
          ],
        },
        {
          'action_name': 'run_service_conformance_test',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'service_conformance_test'
            '<(EXECUTABLE_SUFFIX)',
            '<(SHARED_INTERMEDIATE_DIR)/service_conformance.snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/service_conformance_test.pass',
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
      'target_name': 'run_myapi_test',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:fletch',
        'copy_dart#host',
        'samples/myapi/myapi.gyp:myapi_test',
        'copy_asan',
      ],
      'actions': [
        {
          'action_name': 'generate_myapi_snapshot',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)dart<(EXECUTABLE_SUFFIX)',
            '-p',
            '<(PRODUCT_DIR)/../../package/',
            '<(PRODUCT_DIR)/../../pkg/fletchc/lib/fletchc.dart',
            'samples/myapi/generated/myapi_service_impl.dart',
          ],
          'inputs': [
            '<(mac_asan_dylib)',
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'dart'
            '<(EXECUTABLE_SUFFIX)',
            # TODO(ahe): Also depend on .dart files in the core libraries.
            'samples/myapi/myapi_impl.dart',
            'samples/myapi/generated/dart/myapi_service.dart',
            'samples/myapi/generated/dart/struct.dart',
          ],
          'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/myapi.snapshot',
          ],
          'action': [
            '<@(_command)',
            '--out',
            '<(SHARED_INTERMEDIATE_DIR)/myapi.snapshot',
          ],
        },
        {
          'action_name': 'run_myapi_test',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'myapi_test'
            '<(EXECUTABLE_SUFFIX)',
            '<(SHARED_INTERMEDIATE_DIR)/myapi.snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/myapi_test.pass',
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
      'target_name': 'run_todomvc_sample',
      # Note: this target_name needs to be different from its dependency.
      # This is due to the ninja GYP generator which doesn't generate unique
      # names.
      'type': 'none',
      'dependencies': [
        'src/vm/vm.gyp:fletch',
        'copy_dart#host',
        'samples/todomvc/todomvc.gyp:todomvc_sample',
        'copy_asan',
      ],
      'actions': [
        {
          'action_name': 'generate_todomvc_snapshot',
          'command': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)dart<(EXECUTABLE_SUFFIX)',
            '-p',
            '<(PRODUCT_DIR)/../../package/',
            '<(PRODUCT_DIR)/../../pkg/fletchc/lib/fletchc.dart',
            'samples/todomvc/todomvc.dart',
          ],
          'inputs': [
            '<(mac_asan_dylib)',
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'dart'
            '<(EXECUTABLE_SUFFIX)',
            # TODO(ahe): Also depend on .dart files in the core libraries.
            'samples/todomvc/model.dart',
            'samples/todomvc/todomvc_impl.dart',
            'samples/todomvc/dart/presentation_graph.dart',
            'samples/todomvc/dart/struct.dart',
            'samples/todomvc/dart/todomvc_service.dart',
            'samples/todomvc/dart/todomvc_presenter.dart',
            'samples/todomvc/dart/todomvc_presenter_model.dart',
          ],
          'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/todomvc.snapshot',
          ],
          'action': [
            '<@(_command)', '--out', '<(SHARED_INTERMEDIATE_DIR)/todomvc.snapshot',
          ],
        },
        {
          'action_name': 'run_todomvc_sample',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'todomvc_sample'
            '<(EXECUTABLE_SUFFIX)',
            '<(SHARED_INTERMEDIATE_DIR)/todomvc.snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/test_outcomes/todomvc_sample.pass',
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
                '../third_party/clang/mac/lib/clang/3.6.0/'
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
