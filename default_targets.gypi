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
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_ia32' ],
      },

      'ReleaseIA32IOS': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_ia32', 'dartino_ios_sim',
          'dartino_clang',
        ],
      },

      'ReleaseIA32Android': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_ia32' ],
        'defines': [ 'DARTINO_TARGET_ANDROID' ],
      },

      'ReleaseIA32Asan': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_ia32', 'dartino_asan',
        ],
      },

      'ReleaseX64': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_x64' ],
      },

      'ReleaseX64Asan': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_x64', 'dartino_asan',
        ],
      },

      'ReleaseIA32Clang': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_ia32', 'dartino_clang',
        ],
      },

      'ReleaseIA32ClangAsan': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_ia32', 'dartino_asan',
          'dartino_clang',
        ],
      },

      'ReleaseX64Clang': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_x64', 'dartino_clang',
        ],
      },

      'ReleaseX64ClangAsan': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_x64', 'dartino_asan',
          'dartino_clang',
        ],
      },

      'ReleaseARM': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_arm' ],
      },

      'ReleaseXARM': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_xarm' ],
      },

      'ReleaseXARMAndroid': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_xarm'],
        'defines': [ 'DARTINO_TARGET_ANDROID' ],
      },

      'ReleaseXARM64': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_xarm64' ],
      },

      'ReleaseMIPS': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_mips' ],
      },

      'ReleaseXMIPS': {
        'inherit_from': [ 'dartino_base', 'dartino_release', 'dartino_xmips' ],
      },

      'DebugIA32': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_ia32', ],
      },

      'DebugIA32Android': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_ia32', ],
        'defines': [ 'DARTINO_TARGET_ANDROID' ],
      },

      'DebugIA32Asan': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_ia32', 'dartino_asan',
        ],
      },

      'DebugX64': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_x64' ],
      },

      'DebugX64Asan': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_x64', 'dartino_asan',
        ],
      },

      'DebugIA32Clang': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_ia32', 'dartino_clang',
        ],
      },

      'DebugIA32ClangAsan': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_ia32', 'dartino_asan',
          'dartino_clang',
        ],
      },

      'DebugX64Clang': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_x64', 'dartino_clang',
        ],
      },

      'DebugX64ClangAsan': {
        'inherit_from': [
          'dartino_base', 'dartino_debug', 'dartino_x64', 'dartino_asan',
          'dartino_clang',
        ],
      },

      'DebugARM': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_arm' ],
      },

      'DebugXARM': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_xarm' ],
      },

      'DebugXARMAndroid': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_xarm' ],
        'defines': [ 'DARTINO_TARGET_ANDROID' ],
      },

      'DebugXARM64': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_xarm64' ],
      },

      'DebugMIPS': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_mips' ],
      },

      'DebugXMIPS': {
        'inherit_from': [ 'dartino_base', 'dartino_debug', 'dartino_xmips' ],
      },

      # Test configuration - to ensure that we can compile this configuration
      'ReleaseIA32DisableDebugging': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_ia32',
          'dartino_disable_debugging'
        ],
      },

      # TODO(herhut): Test configuration - to be removed.
      'ReleaseIA32DisableFFI': {
        'inherit_from': [
          'dartino_base', 'dartino_release', 'dartino_ia32',
          'dartino_disable_ffi'
        ],
      },
    },
  },
}

