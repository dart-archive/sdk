# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# TODO(ahe): Move this file elsewhere?

{
  'includes': [
    'common.gypi'
  ],

  'target_defaults': {

    'configurations': {

      'ReleaseIA32': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_ia32'],
      },

      'DebugIA32': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_ia32'],
      },
    },
  },
}

