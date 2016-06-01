# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
    {
      'target_name': 'serial_port',
      'type': 'shared_library',
      'include_dirs': [
        '../../../third_party/dart/runtime',
      ],
      'variables': {
        'source_path': '../../../third_party/serial_port/lib/src/native',
      },
      'cflags!': [
        '-Wnon-virtual-dtor',
        '-Woverloaded-virtual',
        '-fno-rtti',
        '-fvisibility-inlines-hidden',
        '-Wno-conversion-null',
      ],
      'sources': [
        '<(source_path)/serial_port.h',
        '<(source_path)/serial_port.cc',
        '<(source_path)/serial_port_posix.cc',
        '<(source_path)/native_helper.h',
        # TODO(sigurdm): Add windows source files when porting to windows
      ],
      'defines': [
        # The only effect of DART_SHARED_LIB is to export the Dart API.
        'DART_SHARED_LIB',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '-framework CoreFoundation',
              '-framework iokit',
              '-undefined', 'dynamic_lookup',
            ],
          },
        }],
        ['OS=="linux"', {
          'cflags': [
            '-fPIC',
          ],
        }],
      ],
    },
  ],
}
