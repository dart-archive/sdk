# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
    {
      'target_name': 'power_management_extension_lib',
      'type': 'shared_library',
      'include_dirs': [
        '../../../third_party/dart/runtime',
      ],
      'cflags!': [
        '-Wnon-virtual-dtor',
        '-Woverloaded-virtual',
        '-fno-rtti',
        '-fvisibility-inlines-hidden',
        '-Wno-conversion-null',
      ],
      'sources': [
        'power_management_extension.cc',
        'power_management_extension_linux.cc',
        'power_management_extension_macos.cc',
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
