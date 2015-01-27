# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# TODO(ahe): Move this file elsewhere?

{
  'variables': {
    'common_gcc_warning_flags': [
      '-Wall',
      '-Wextra', # Also known as -W.
      '-Wno-unused-parameter',
    ],
  },
  'target_defaults': {
    'configurations': {

      'fletch_base': {
        'abstract': 1,

        'xcode_settings': {
          # Settings for Xcode and ninja. Huh? Yeah, GYP is awesome!

          'GCC_C_LANGUAGE_STANDARD': 'ansi',
          'GCC_TREAT_WARNINGS_AS_ERRORS': 'YES', # -Werror
          'GCC_WARN_NON_VIRTUAL_DESTRUCTOR': 'NO', # -Wno-non-virtual-dtor
          'GCC_ENABLE_CPP_RTTI': 'NO', # -fno-rtti
          'GCC_ENABLE_CPP_EXCEPTIONS': 'NO', # -fno-exceptions

          'OTHER_CPLUSPLUSFLAGS' : [
            '-std=c++11',
            '-stdlib=libc++',
            '-fdata-sections',
            '-ffunction-sections',
            '-O3',
            '-fomit-frame-pointer',
          ],
          'WARNING_CFLAGS': [
            '<@(common_gcc_warning_flags)',
            '-Wtrigraphs', # Disable Xcode default.
            '-Wno-format',
          ],
        },
      },

      'fletch_release': {
        'abstract': 1,

        'defines': [
          'NDEBUG', # TODO(ahe): Is this necessary/used?
        ],

        'xcode_settings': { # And ninja.
          'OTHER_CPLUSPLUSFLAGS' : [
            '-O3',
          ],
        },
      },

      'fletch_debug': {
        'abstract': 1,

        'defines': [
          'DEBUG',
        ],

        'xcode_settings': { # And ninja.
          'OTHER_CPLUSPLUSFLAGS' : [
            '-g',
            '-O0',
          ],
        },
      },

      'fletch_ia32': {
        'abstract': 1,

        'defines': [
          'FLETCH32',
        ],

        'xcode_settings': { # And ninja.
          'ARCHS': [ 'i386' ],
        },
      },

      'fletch_x64': {
        'abstract': 1,

        'defines': [
          'FLETCH64',
        ],

        'xcode_settings': { # And ninja.
          'ARCHS': [ 'x86_64' ],
        },
      },

      'ReleaseIA32': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_ia32' ],
      },

      'ReleaseX64': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_x64' ],
      },

      'DebugIA32': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_ia32' ],
      },

      'DebugX64': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_x64' ],
      },
    },
    # TODO(ahe): These flags should be incorporated in all executables:
    # LINKER_FLAGS=-rdynamic -Lthird_party/libs/macos/x86
    # LIBS=-ltcmalloc_minimal -lpthread -ldl
  },
}
