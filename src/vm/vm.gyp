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
      'target_name': 'fletch_vm_library_base',
      'type': 'static_library',
      'toolsets': ['target', 'host'],
      'dependencies': [
        '../shared/shared.gyp:fletch_shared',
        '../double_conversion.gyp:double_conversion',
      ],
      'conditions': [
        [ 'OS=="mac"', {
          'dependencies': [
            '../shared/shared.gyp:copy_asan#host',
          ],
          'sources': [
            '<(PRODUCT_DIR)/libclang_rt.asan_osx_dynamic.dylib',
          ],
        }],
      ],
      'sources': [
        'debug_info.cc',
        'debug_info.h',
        'debug_info_no_live_coding.h',
        'event_handler.h',
        'event_handler.cc',
        'event_handler_posix.cc',
        'event_handler_linux.cc',
        'event_handler_macos.cc',
        'event_handler_lk.cc',
        'event_handler_cmsis.cc',
        'ffi.cc',
        'ffi_disabled.cc',
        'ffi_static.cc',
        'ffi.h',
        'ffi_linux.cc',
        'ffi_macos.cc',
        'ffi_posix.cc',
        'fletch_api_impl.cc',
        'fletch_api_impl.h',
        'fletch.cc',
        'gc_thread.cc',
        'gc_thread.h',
        'hash_map.h',
        'hash_set.h',
        'hash_table.h',
        'heap.cc',
        'heap.h',
        'heap_validator.cc',
        'heap_validator.h',
        'shared_heap.cc',
        'shared_heap.h',
        'interpreter.cc',
        'interpreter.h',
        'intrinsics.cc',
        'intrinsics.h',
        'log_print_interceptor.cc',
        'log_print_interceptor.h',
        'lookup_cache.cc',
        'lookup_cache.h',
        'mailbox.h',
        'message_mailbox.h',
        'message_mailbox.cc',
        'native_interpreter.h',
        'native_process.cc',
        'native_process_disabled.cc',
        'natives.cc',
        'natives_posix.cc',
        'natives_lk.cc',
        'natives_cmsis.cc',
        'natives.h',
        'object.cc',
        'object.h',
        'object_list.cc',
        'object_list.h',
        'object_map.cc',
        'object_map.h',
        'object_memory.cc',
        'object_memory.h',
        'pair.h',
        'port.cc',
        'port.h',
        'process_handle.h',
        'process.cc',
        'process.h',
        'process_queue.h',
        'program.cc',
        'program.h',
        'program_folder.cc',
        'program_folder.h',
        'program_info_block.cc',
        'program_info_block.h',
        'scheduler.cc',
        'scheduler.h',
        'selector_row.cc',
        'selector_row.h',
        'service_api_impl.cc',
        'service_api_impl.h',
        'session.cc',
        'session.h',
        'session_no_live_coding.h',
        'snapshot.cc',
        'snapshot.h',
        'sort.h',
        'sort.cc',
        'stack_walker.cc',
        'stack_walker.h',
        'storebuffer.cc',
        'storebuffer.h',
        'thread.h',
        'thread_pool.cc',
        'thread_pool.h',
        'thread_posix.cc',
        'thread_posix.h',
        'thread_lk.cc',
        'thread_lk.h',
        'thread_cmsis.cc',
        'thread_cmsis.h',
        'unicode.cc',
        'unicode.h',
        'vector.cc',
        'vector.h',
        'void_hash_table.cc',
        'void_hash_table.h',
        'weak_pointer.cc',
        'weak_pointer.h',
      ],
      'link_settings': {
        'libraries': [
          '-lpthread',
          '-ldl',
          # TODO(ahe): Not sure this option works as intended on Mac.
          '-rdynamic',
        ],
      },
    },
    {
      'target_name': 'fletch_vm_library',
      'type': 'static_library',
      'dependencies': [
        'fletch_vm_library_generator#host',
        'fletch_vm_library_base',
        '../shared/shared.gyp:fletch_shared',
        '../double_conversion.gyp:double_conversion',
      ],

      # TODO(kasperl): Remove the below conditions when we no longer use weak
      # symbols.
      'conditions': [
        [ 'OS=="linux"', {
          'link_settings': {
            'ldflags': [
              '-Wl,--whole-archive',
            ],
            'libraries': [
              '-Wl,--no-whole-archive',
            ],
          },
        }],
      ],

      'sources': [
        '<(INTERMEDIATE_DIR)/generated.S',
      ],
      'actions': [
        {
          'action_name': 'generate_generated_S',
          'inputs': [
            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)'
            'fletch_vm_library_generator'
            '<(EXECUTABLE_SUFFIX)',
          ],
          'outputs': [
            '<(INTERMEDIATE_DIR)/generated.S',
          ],
          'action': [
            # TODO(ahe): Change generator to accept command line argument for
            # output file. Using file redirection may not work well on Windows.
            'bash', '-c', '<(_inputs) > <(_outputs)',
          ],
        },
      ],
    },
    {
      'target_name': 'libfletch',
      'type': 'none',
      'dependencies': [
        'fletch_vm_library',
        'fletch_vm_library_base',
        '../shared/shared.gyp:fletch_shared',
        '../double_conversion.gyp:double_conversion',
      ],
      'sources': [
        # TODO(ager): Lint target default requires a source file. Not
        # sure how to work around that.
        'assembler.h',
      ],
      'actions': [
        {
          'action_name': 'generate_libfletch',
          'conditions': [
            [ 'OS=="linux"', {
              'inputs': [
                '../../tools/library_combiner.py',
                '<(PRODUCT_DIR)/obj/src/vm/libfletch_vm_library.a',
                '<(PRODUCT_DIR)/obj/src/vm/libfletch_vm_library_base.a',
                '<(PRODUCT_DIR)/obj/src/shared/libfletch_shared.a',
                '<(PRODUCT_DIR)/obj/src/libdouble_conversion.a',
              ],
            }],
            [ 'OS=="mac"', {
              'inputs': [
                '../../tools/library_combiner.py',
                '<(PRODUCT_DIR)/libfletch_vm_library.a',
                '<(PRODUCT_DIR)/libfletch_vm_library_base.a',
                '<(PRODUCT_DIR)/libfletch_shared.a',
                '<(PRODUCT_DIR)/libdouble_conversion.a',
              ],
            }],
          ],
          'outputs': [
            '<(PRODUCT_DIR)/libfletch.a',
          ],
          'action': [
            'bash', '-c', 'python <(_inputs) <(_outputs)',
          ]
        },
      ]
    },
    {
      'target_name': 'fletch_vm_library_generator',
      'type': 'executable',
      'toolsets': ['host'],
      'dependencies': [
        '../shared/shared.gyp:fletch_shared',
        '../double_conversion.gyp:double_conversion',
      ],
      'conditions': [
        [ 'OS=="mac"', {
          'dependencies': [
            '../shared/shared.gyp:copy_asan#host',
          ],
          'sources': [
            '<(PRODUCT_DIR)/libclang_rt.asan_osx_dynamic.dylib',
          ],
        }],
      ],
      'sources': [
        'assembler_arm64_linux.cc',
        'assembler_arm64_macos.cc',
        'assembler_arm.cc',
        'assembler_arm.h',
        'assembler_arm_thumb_linux.cc',
        'assembler_arm_linux.cc',
        'assembler_arm_macos.cc',
        'assembler.h',
        'assembler_x64.cc',
        'assembler_x64.h',
        'assembler_x64_linux.cc',
        'assembler_x64_macos.cc',
        'assembler_x86.cc',
        'assembler_x86.h',
        'assembler_x86_linux.cc',
        'assembler_x86_macos.cc',
        'generator.h',
        'generator.cc',
        'interpreter_arm.cc',
        'interpreter_x86.cc',
      ],
    },
    {
      'target_name': 'fletch-vm',
      'type': 'executable',
      'dependencies': [
        'libfletch',
      ],
      'sources': [
        'main.cc',
        'main_simple.cc',
      ],
    },
    {
      'target_name': 'vm_cc_tests',
      'type': 'executable',
      'dependencies': [
        'libfletch',
        '../shared/shared.gyp:cc_test_base',
      ],
      'defines': [
        'TESTING',
        # TODO(ahe): Remove this when GYP is the default.
        'GYP',
      ],
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'hash_table_test.cc',
        'object_map_test.cc',
        'object_memory_test.cc',
        'object_test.cc',
        'platform_test.cc',
        'vector_test.cc',
      ],
    },
    {
      'target_name': 'ffi_test_library',
      'type': 'shared_library',
      'dependencies': [
      ],
      'sources': [
        'ffi_test_library.h',
        'ffi_test_library.c',
      ],
      'cflags': ['-fPIC'],
      'xcode_settings': {
        'OTHER_CPLUSPLUSFLAGS': [
          '-fPIC',
        ],
      },
    },
  ],
}
