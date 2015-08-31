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
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_ia32' ],
      },

      'ReleaseIA32Android': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_ia32' ],
        'defines': [ 'FLETCH_TARGET_ANDROID' ],
      },

      'ReleaseIA32Asan': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_ia32', 'fletch_asan',
        ],
      },

      'ReleaseX64': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_x64' ],
      },

      'ReleaseX64Asan': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_x64', 'fletch_asan',
        ],
      },

      'ReleaseIA32Clang': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_ia32', 'fletch_clang',
        ],
      },

      'ReleaseIA32ClangAsan': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_ia32', 'fletch_asan',
          'fletch_clang',
        ],
      },

      'ReleaseX64Clang': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_x64', 'fletch_clang',
        ],
      },

      'ReleaseX64ClangAsan': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_x64', 'fletch_asan',
          'fletch_clang',
        ],
      },

      'ReleaseARM': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_arm' ],
      },

      'ReleaseXARM': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_xarm' ],
      },

      'ReleaseXARMAndroid': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_xarm'],
        'defines': [ 'FLETCH_TARGET_ANDROID' ],
      },

      'ReleaseXARM64': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_xarm64' ],
      },

      'DebugIA32': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_ia32', ],
      },

      'DebugIA32Android': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_ia32', ],
        'defines': [ 'FLETCH_TARGET_ANDROID' ],
      },

      'DebugIA32Asan': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_ia32', 'fletch_asan',
        ],
      },

      'DebugX64': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_x64' ],
      },

      'DebugX64Asan': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_x64', 'fletch_asan',
        ],
      },

      'DebugIA32Clang': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_ia32', 'fletch_clang',
        ],
      },

      'DebugIA32ClangAsan': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_ia32', 'fletch_asan',
          'fletch_clang',
        ],
      },

      'DebugX64Clang': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_x64', 'fletch_clang',
        ],
      },

      'DebugX64ClangAsan': {
        'inherit_from': [
          'fletch_base', 'fletch_debug', 'fletch_x64', 'fletch_asan',
          'fletch_clang',
        ],
      },

      'DebugARM': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_arm' ],
      },

      'DebugXARM': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_xarm' ],
      },

      'DebugXARMAndroid': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_xarm' ],
        'defines': [ 'FLETCH_TARGET_ANDROID' ],
      },

      'DebugXARM64': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_xarm64' ],
      },

      'DevelopIA32': {
        'inherit_from': [ 'fletch_base', 'fletch_develop', 'fletch_ia32', ],
      },

      'DevelopIA32Android': {
        'inherit_from': [ 'fletch_base', 'fletch_develop', 'fletch_ia32', ],
        'defines': [ 'FLETCH_TARGET_ANDROID' ],
      },

      'DevelopIA32Asan': {
        'inherit_from': [
          'fletch_base', 'fletch_develop', 'fletch_ia32', 'fletch_asan',
        ],
      },

      'DevelopX64': {
        'inherit_from': [ 'fletch_base', 'fletch_develop', 'fletch_x64' ],
      },

      'DevelopX64Asan': {
        'inherit_from': [
          'fletch_base', 'fletch_develop', 'fletch_x64', 'fletch_asan',
        ],
      },

      'DevelopIA32Clang': {
        'inherit_from': [
          'fletch_base', 'fletch_develop', 'fletch_ia32', 'fletch_clang',
        ],
      },

      'DevelopIA32ClangAsan': {
        'inherit_from': [
          'fletch_base', 'fletch_develop', 'fletch_ia32', 'fletch_asan',
          'fletch_clang',
        ],
      },

      'DevelopX64Clang': {
        'inherit_from': [
          'fletch_base', 'fletch_develop', 'fletch_x64', 'fletch_clang',
        ],
      },

      'DevelopX64ClangAsan': {
        'inherit_from': [
          'fletch_base', 'fletch_develop', 'fletch_x64', 'fletch_asan',
          'fletch_clang',
        ],
      },

      'DevelopARM': {
        'inherit_from': [ 'fletch_base', 'fletch_develop', 'fletch_arm' ],
      },

      'DevelopXARM': {
        'inherit_from': [ 'fletch_base', 'fletch_develop', 'fletch_xarm' ],
      },

      'DevelopXARMAndroid': {
        'inherit_from': [ 'fletch_base', 'fletch_develop', 'fletch_xarm' ],
        'defines': [ 'FLETCH_TARGET_ANDROID' ],
      },

      'DevelopXARM64': {
        'inherit_from': [ 'fletch_base', 'fletch_develop', 'fletch_xarm64' ],
      },

      # TODO(ajohnsen): Test configuration - to be removed.
      'ReleaseIA32DisableLiveCoding': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_ia32',
          'fletch_disable_live_coding'
        ],
      },

      # TODO(herhut): Test configuration - to be removed.
      'ReleaseIA32DisableFFI': {
        'inherit_from': [
          'fletch_base', 'fletch_release', 'fletch_ia32',
          'fletch_disable_ffi'
        ],
      },
    },
  },
}

