# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
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
      'target_name': 'dartino_shared',
      'type': 'static_library',
      'toolsets': ['target', 'host'],
      'conditions': [
        ['OS=="win"', {
          'all_dependent_settings': {
	    'link_settings': {
	      'libraries': [
		'-lws2_32.lib',
	      ],
	    },
	  },
	}],
      ],
      'target_conditions': [
        ['_toolset == "target"', {
          'standalone_static_library': 1,
	}]],
      'dependencies': [
        '../../version.gyp:generate_version_cc#host',
      ],
      'sources': [
        'asan_helper.h',
        'assert.cc',
        'assert.h',
        'atomic.h',
        'bytecodes.cc',
        'bytecodes.h',
        'connection.cc',
        'connection.h',
        'socket_connection.cc',
        'socket_connection.h',
        'flags.cc',
        'flags.h',
        'dartino.h',
        'globals.h',
        'list.h',
        'names.h',
        'native_socket.h',
        'native_socket_linux.cc',
        'native_socket_lk.cc',
        'native_socket_macos.cc',
        'native_socket_posix.cc',
        'native_socket_windows.cc',
        'natives.h',
        'platform.h',
        'platform_linux.cc',
        'platform_lk.cc',
        'platform_lk.h',
        'platform_macos.cc',
        'platform_cmsis.cc',
        'platform_cmsis.h',
        'platform_posix.cc',
        'platform_posix.h',
        'platform_vm.cc',
        'platform_windows.cc',
        'platform_windows.h',
        'random.h',
        'selectors.h',
        'utils.cc',
        'utils.h',
        'version.h',

        '<(SHARED_INTERMEDIATE_DIR)/version.cc',
      ],
    },
    {
      'target_name': 'cc_test_base',
      'type': 'static_library',
      'dependencies': [
        'dartino_shared',
      ],
      'sources': [
        'test_case.h',
        'test_case.cc',
        'test_main.cc',
      ],
    },
    {
      'target_name': 'shared_cc_tests',
      'type': 'executable',
      'dependencies': [
        'cc_test_base',
      ],
      'defines': [
        'TESTING',
      ],
      'sources': [
        'assert_test.cc',
        'flags_test.cc',
        'globals_test.cc',
        'random_test.cc',
        'utils_test.cc',
        'dartino.cc',
      ],
    },
    {
      'target_name': 'natives_to_json',
      'type': 'executable',
      'toolsets': ['host'],
      'dependencies': [
        'dartino_shared',
      ],
      'sources': [
        'natives_to_json.cc',
      ],
      'conditions': [
        [ 'OS=="mac"', {
          'dependencies': [
            'copy_asan#host',
          ],
          'sources': [
            '<(PRODUCT_DIR)/libclang_rt.asan_osx_dynamic.dylib',
          ],
        }],
      ],
    },
    {
      'target_name': 'natives_json',
      'type': 'none',
      'toolsets': ['target'],
      'dependencies': [
        'natives_to_json#host',
      ],
      'actions': [
        {
          'action_name': 'make_natives_json',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'natives_to_json'
            '<(EXECUTABLE_SUFFIX)',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/natives.json',
          ],
          'action': [
            '<@(_inputs)',
            '<@(_outputs)',
          ],
        }
      ],
    }
  ],
  'conditions': [
    [ 'OS=="mac"', {
      'targets': [
        {
          'target_name': 'copy_asan',
          'type': 'none',
          'toolsets': ['host'],
          'copies': [
            {
              # The asan dylib file sets its install name as
              # @executable_path/..., and by copying to PRODUCT_DIR, we avoid
              # having to set DYLD_LIBRARY_PATH.
              'destination': '<(PRODUCT_DIR)',
              'files': [
                '../../third_party/clang/mac/lib/clang/3.8.0/'
                'lib/darwin/libclang_rt.asan_osx_dynamic.dylib',
              ],
            },
          ],
        },
      ]
    }]
  ],
}
