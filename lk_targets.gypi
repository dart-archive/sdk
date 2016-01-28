# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# TODO(ahe): Move this file elsewhere?

{
  'includes': [
    'common.gypi'
  ],

  'variables': {
    'LK_PROJECT%': 'qemu-virt-fletch',

    'LK_CPU%': 'cortex-a15',
  },

  'target_defaults': {

    'configurations': {

      'fletch_lk_flags': {
        'abstract': 1,

        'inherit_from': ['fletch_lk'],

        'target_conditions': [
          ['_toolset=="target"', {
            'cflags': [
              '-mcpu=<(LK_CPU)',
              '-include',
              'build-<(LK_PROJECT)/config.h',
            ],
          }],
        ],
      },

      'DebugLK': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_lk_flags',
          'fletch_disable_live_coding',
          'fletch_disable_native_processes',
          'fletch_disable_print_interceptors',
        ],
      },

      'ReleaseLK': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_lk_flags',
          'fletch_disable_live_coding',
          'fletch_disable_native_processes',
          'fletch_disable_print_interceptors',
        ],
      },

      'DebugLKFull': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_lk_flags',
          'fletch_disable_native_processes',
          'fletch_disable_print_interceptors',
        ],
      },

      'ReleaseLKFull': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_lk_flags',
          'fletch_disable_native_processes',
          'fletch_disable_print_interceptors',
        ],
      },
    },
  },
}
