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

      'ReleaseMBED': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_mbed',
          'dartino_disable_live_coding', 'dartino_disable_ffi',
          'dartino_disable_native_processes',
          'dartino_disable_print_interceptors'],
      },

      'DebugMBED': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_mbed',
          'dartino_disable_live_coding', 'dartino_disable_ffi',
          'dartino_disable_native_processes',
          'dartino_disable_print_interceptors'],
      },
    },
  },
}
