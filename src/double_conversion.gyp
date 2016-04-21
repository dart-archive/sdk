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
      'target_name': 'double_conversion',
      'type': 'static_library',
      'target_conditions': [
        ['_toolset == "target"', {
          'standalone_static_library': 1,
      }]],
      'toolsets': ['target', 'host'],
      'sources': [
        '../third_party/double-conversion/src/bignum-dtoa.cc',
        '../third_party/double-conversion/src/bignum-dtoa.h',
        '../third_party/double-conversion/src/bignum.cc',
        '../third_party/double-conversion/src/bignum.h',
        '../third_party/double-conversion/src/cached-powers.cc',
        '../third_party/double-conversion/src/cached-powers.h',
        '../third_party/double-conversion/src/diy-fp.cc',
        '../third_party/double-conversion/src/diy-fp.h',
        '../third_party/double-conversion/src/double-conversion.cc',
        '../third_party/double-conversion/src/double-conversion.h',
        '../third_party/double-conversion/src/ieee.h',
        '../third_party/double-conversion/src/strtod.cc',
        '../third_party/double-conversion/src/strtod.h',
        '../third_party/double-conversion/src/utils.h',
      ],
    },
  ],
}
