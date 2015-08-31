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

      'DebugLK': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_lk',
          'fletch_disable_live_coding', 'fletch_disable_ffi',
          'fletch_disable_print_interceptors',
        ],
      },

      'ReleaseLK': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_lk',
          'fletch_disable_live_coding', 'fletch_disable_ffi',
          'fletch_disable_print_interceptors',
        ],
      },
    },
  },
}
