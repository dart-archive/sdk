# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
    {
      'target_name': 'fletch_vm',
      'type': 'static_library',
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'assembler_x86.cc',
        'assembler_x86_macos.cc',
        'event_handler.cc',
        'event_handler_macos.cc',
        'ffi.cc',
        'fletch.cc',
        'fletch_api_impl.cc',
        'heap.cc',
        'interpreter.cc',
        'intrinsics.cc',
        'lookup_cache.cc',
        'natives.cc',
        'object.cc',
        'object_list.cc',
        'object_map.cc',
        'object_memory.cc',
        'platform_posix.cc',
        'port.cc',
        'process.cc',
        'program.cc',
        'scheduler.cc',
        'service_api_impl.cc',
        'session.cc',
        'snapshot.cc',
        'stack_walker.cc',
        'thread_pool.cc',
        'thread_posix.cc',
        'weak_pointer.cc',

        # TODO(ahe): Depend on libfletch_shared instead.
        '../shared/assert.cc',
        '../shared/bytecodes.cc',
        '../shared/connection.cc',
        '../shared/flags.cc',
        '../shared/native_process_posix.cc',
        '../shared/native_socket_macos.cc',
        '../shared/native_socket_posix.cc',
        '../shared/test_case.cc',
        '../shared/utils.cc',

        # TODO(ahe): Create GYP file for double-conversion instead.
        '../../third_party/double-conversion/src/bignum-dtoa.cc',
        '../../third_party/double-conversion/src/bignum.cc',
        '../../third_party/double-conversion/src/cached-powers.cc',
        '../../third_party/double-conversion/src/diy-fp.cc',
        '../../third_party/double-conversion/src/double-conversion.cc',
        '../../third_party/double-conversion/src/fast-dtoa.cc',
        '../../third_party/double-conversion/src/fixed-dtoa.cc',
        '../../third_party/double-conversion/src/strtod.cc',

        # TODO(ahe): Generate generated.o.
        # 'vm/generated.o',
      ],
      'include_dirs': [
        '../../',
      ],
    },
    {
      'target_name': 'fletch_vm_generator',
      'type': 'executable',
      'include_dirs': [
        '../../',
      ],
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'generator.cc',

        # TODO(ahe): Depend on libfletch_vm instead.
        'assembler_x86.cc',
        'assembler_x86_macos.cc',
        'event_handler.cc',
        'event_handler_macos.cc',
        'ffi.cc',
        'fletch.cc',
        'fletch_api_impl.cc',
        'heap.cc',
        'interpreter.cc',
        'interpreter_x86.cc',
        'intrinsics.cc',
        'lookup_cache.cc',
        'natives.cc',
        'natives_x86.cc',
        'object.cc',
        'object_list.cc',
        'object_map.cc',
        'object_memory.cc',
        'platform_posix.cc',
        'port.cc',
        'process.cc',
        'program.cc',
        'scheduler.cc',
        'service_api_impl.cc',
        'session.cc',
        'snapshot.cc',
        'stack_walker.cc',
        'thread_pool.cc',
        'thread_posix.cc',
        'weak_pointer.cc',

        '../shared/assert.cc',
        '../shared/bytecodes.cc',
        '../shared/connection.cc',
        '../shared/flags.cc',
        '../shared/native_process_posix.cc',
        '../shared/native_socket_macos.cc',
        '../shared/native_socket_posix.cc',
        '../shared/test_case.cc',
        '../shared/utils.cc',

        '../../third_party/double-conversion/src/bignum-dtoa.cc',
        '../../third_party/double-conversion/src/bignum.cc',
        '../../third_party/double-conversion/src/cached-powers.cc',
        '../../third_party/double-conversion/src/diy-fp.cc',
        '../../third_party/double-conversion/src/double-conversion.cc',
        '../../third_party/double-conversion/src/fast-dtoa.cc',
        '../../third_party/double-conversion/src/fixed-dtoa.cc',
        '../../third_party/double-conversion/src/strtod.cc',
      ],

      # TODO(ahe): Add these options to linker:
      # -m32
      # -rdynamic
      # -Lthird_party/libs/macos/x86
      # ... o files ...
      # -ltcmalloc_minimal
      # -lpthread
      # -ldl
    },
  ],
}
