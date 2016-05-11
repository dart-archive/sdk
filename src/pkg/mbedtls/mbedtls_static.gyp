# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
    {
      'target_name': 'mbedtls',
      'type': 'static_library',
      'standalone_static_library': 1,
      'includes': [
        'mbedtls_sources.gypi',
      ],
      'cflags_c!': [
        '-fvisibility=hidden',
      ],
      'xcode_settings': {
        'OTHER_CFLAGS': [
          '-std=c99', # clang on mac does not like inline unless we explicitly use c99.
        ],
      },
      'defines': [
        'MBEDTLS_CONFIG_FILE=<mbedtls_config.h>',
      ],
      'sources': [
        'bindings.c',
      ],
      'include_dirs': [
        '.',
      ],
      'conditions': [
        ['OS=="linux"', {
          'cflags': [
            '-fPIC',
            '-fomit-frame-pointer',
          ],
        }],
      ],
    },
  ],
}
