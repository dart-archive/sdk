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
      'target_name': 'fletch_compiler',
      'type': 'static_library',
      'dependencies': [
        '../shared/shared.gyp:fletch_shared',
      ],
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
      ],
    },
    {
      'target_name': 'fletchc',
      'type': 'executable',
      'dependencies': [
        'fletch_compiler',
      ],
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'main.cc',
      ],
    },
    {
      'target_name': 'fletchc_scan',
      'type': 'executable',
      'dependencies': [
        'fletch_compiler',
      ],
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'scan.cc',
      ],
    },
    {
      'target_name': 'bench',
      'type': 'executable',
      'dependencies': [
        'fletch_compiler',
      ],
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'bench.cc',
      ],
    },
    {
      'target_name': 'fletchc_print',
      'type': 'executable',
      'dependencies': [
        'fletch_compiler',
      ],
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'print.cc',
      ],
    },
    {
      'target_name': 'compiler_run_tests',
      'type': 'executable',
      'dependencies': [
        'fletch_compiler',
      ],
      'defines': [
        'TESTING',
      ],
      'sources': [
        # TODO(ahe): Add header (.h) files.
        'builder_test.cc',
        'compiler_test.cc',
        'list_test.cc',
        'parser_test.cc',
        'scanner_test.cc',
        'zone_test.cc',

        # TODO(ahe): Depend on library?
        '../shared/test_main.cc',
      ],
    },
  ],
}
