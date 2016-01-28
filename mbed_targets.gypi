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
          'fletch_base', 'fletch_release', 'fletch_mbed',
          'fletch_disable_live_coding', 'fletch_disable_ffi', 
          'fletch_disable_native_processes',
          'fletch_disable_print_interceptors'],
      },

      'DebugMBED': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_mbed', 
          'fletch_disable_live_coding', 'fletch_disable_ffi', 
          'fletch_disable_native_processes',
          'fletch_disable_print_interceptors'],
      },
    },
  },
}
