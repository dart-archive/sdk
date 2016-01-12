# Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
    {
      'target_name': 'mbedtls_static',
      'type': 'static_library',
      'includes': [
        'mbedtls_sources.gypi',
      ],
      'cflags_c!': [
        '-fvisibility=hidden',
      ],
      'sources': [
        'bindings.c',
      ],
      'conditions': [
        ['OS=="linux"', {
          'cflags': [
            '-fPIC',
          ],
        }],
      ],
    },
    {
      'target_name': 'mbedtls',
      'type': 'shared_library',
      'dependencies': [
        'mbedtls_static',
      ],
    },
  ],
}
