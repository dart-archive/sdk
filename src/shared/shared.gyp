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
      'target_name': 'fletch_shared',
      'type': 'static_library',
      'toolsets': ['target', 'host'],
      'sources': [
        'asan_helper.h',
        'assert.cc',
        'assert.h',
        'atomic.h',
        'bytecodes.cc',
        'bytecodes.h',
        'connection.cc',
        'connection.h',
        'flags.cc',
        'flags.h',
        'fletch.h',
        'globals.h',
        'list.h',
        'names.h',
        'natives.h',
        'native_socket.h',
        'native_socket_linux.cc',
        'native_socket_macos.cc',
        'native_socket_posix.cc',
        'platform.h',
        'platform_linux.cc',
        'platform_macos.cc',
        'platform_posix.cc',
        'random.h',
        'selectors.h',
        'utils.cc',
        'utils.h',
      ],
      'link_settings': {
        'libraries': [
          '-lpthread',
        ],
      },
    },
    {
      'target_name': 'cc_test_base',
      'type': 'static_library',
      'dependencies': [
        'fletch_shared',
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
        'fletch.cc',
      ],
    },
    {
      'target_name': 'natives_to_json',
      'type': 'executable',
      'toolsets': ['host'],
      'dependencies': [
        'fletch_shared',
      ],
      'sources': [
        'natives_to_json.cc',
      ],
    },
    {
      'target_name': 'natives_json',
      'type': 'none',
      'toolsets': ['host'],
      'dependencies': [
        'natives_to_json',
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
}
