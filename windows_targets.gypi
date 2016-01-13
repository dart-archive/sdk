# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
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
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_ia32',
                          'fletch_disable_native_processes' ],
      },

      'ReleaseX64': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_x64',
                          'fletch_disable_native_processes' ],
      },

      'DebugIA32': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_ia32',
                          'fletch_disable_native_processes' ],
      },

      'DebugX64': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_x64',
                          'fletch_disable_native_processes' ],
      },
    },
  },
}

