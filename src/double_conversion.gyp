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
      'target_name': 'double_conversion',
      'type': 'static_library',
      'sources': [
        # TODO(ahe): Include header (.h) files.
        '../third_party/double-conversion/src/bignum-dtoa.cc',
        '../third_party/double-conversion/src/bignum.cc',
        '../third_party/double-conversion/src/cached-powers.cc',
        '../third_party/double-conversion/src/diy-fp.cc',
        '../third_party/double-conversion/src/double-conversion.cc',
        '../third_party/double-conversion/src/fast-dtoa.cc',
        '../third_party/double-conversion/src/fixed-dtoa.cc',
        '../third_party/double-conversion/src/strtod.cc',
      ],
    },
  ],
}
