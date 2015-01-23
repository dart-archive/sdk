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
      'Default': {
        'defines': [
          'FLETCH32',
          'NDEBUG', # TODO(ahe): Is this necessary/used?
        ],
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
            '-m32',
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
    },
  },
}
