# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# TODO(ahe): Move this file elsewhere?

{
  'includes': [
    'common.gypi'
  ],

  'variables': {
    'LK_PROJECT%': 'qemu-virt-dartino',

    'LK_CPU%': 'cortex-a15',
    'LK_FPU%': 'vfpv4',
    'LK_FLOAT-ABI%': 'hard',
  },

  'target_defaults': {

    'configurations': {

      'dartino_lk_flags': {
        'abstract': 1,

        'inherit_from': [
	  'dartino_lk',
	  'dartino_use_single_precision',
	],

        'target_conditions': [
          ['_toolset=="target"', {
            'cflags': [
              '-mcpu=<(LK_CPU)',
	      '-mfpu=<(LK_FPU)',
	      '-mfloat-abi=<(LK_FLOAT-ABI)',
              '-include',
              'build-<(LK_PROJECT)/config.h',
            ],
          }],
        ],
      },

      'DebugLK': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_lk_flags',
          'dartino_disable_live_coding',
          'dartino_disable_native_processes',
          'dartino_disable_print_interceptors',
        ],
      },

      'ReleaseLK': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_lk_flags',
          'dartino_disable_live_coding',
          'dartino_disable_native_processes',
          'dartino_disable_print_interceptors',
        ],
      },

      'DebugLKFull': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_lk_flags',
          'dartino_disable_native_processes',
          'dartino_disable_print_interceptors',
        ],
      },

      'ReleaseLKFull': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_lk_flags',
          'dartino_disable_native_processes',
          'dartino_disable_print_interceptors',
        ],
      },
    },
  },
}
