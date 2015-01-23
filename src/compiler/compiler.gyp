# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
    {
      'target_name': 'fletch_compiler',
      'type': 'static_library',
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'allocation.cc',
        'builder.cc',
        'class_visitor.cc',
        'compiler.cc',
        'const_interpreter.cc',
        'emitter.cc',
        'fletch.cc',
        'library_loader.cc',
        'map.cc',
        'os.cc',
        'parser.cc',
        'pretty_printer.cc',
        'resolver.cc',
        'scanner.cc',
        'scope.cc',
        'scope_resolver.cc',
        'session.cc',
        'source.cc',
        'string_buffer.cc',
        'tokens.cc',
        'tree.cc',
        'zone.cc',

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
      ],
      'include_dirs': [
        '../../',
      ],
    },
  ],
}
