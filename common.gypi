# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# TODO(ahe): Move this file elsewhere?

{
  'variables': {
    'clang%': '0',

    'common_gcc_warning_flags': [
      '-Wall',
      '-Wextra', # Also known as -W.
      '-Wno-unused-parameter',
      '-Wno-format',
      '-Wno-comment',
    ],

    'common_gcc_cflags': [
      '-std=c++11',
      '-fdata-sections',
      '-ffunction-sections',
      '-fPIC',
    ],

    'conditions': [
      [ 'OS=="linux"', {
        'clang_asan_rt_path%': '.',
        'third_party_libs_path%': '<(DEPTH)/third_party/libs/linux',
      }],
      [ 'OS=="mac"', {
        'clang_asan_rt_path%':
          '<(DEPTH)/third_party/clang/mac/lib/clang/3.6.0/'
          'lib/darwin/libclang_rt.asan_osx_dynamic.dylib',
        'third_party_libs_path%': '<(DEPTH)/third_party/libs/mac',
      }],
      [ 'OS=="win"', {
        'clang_asan_rt_path%': '.',
        'third_party_libs_path%': '<(DEPTH)/third_party/libs/win',
      }],
    ],
  },

  'make_global_settings': [
    [ 'CC', 'tools/cc_wrapper.py' ],
    [ 'CXX', 'tools/cxx_wrapper.py' ],
    [ 'LINK', 'tools/cc_wrapper.py' ],
  ],

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
            '<@(common_gcc_cflags)',
            '-stdlib=libc++',
          ],

          'WARNING_CFLAGS': [
            '<@(common_gcc_warning_flags)',
            '-Wtrigraphs', # Disable Xcode default.
          ],
        },

        'cflags': [
          '<@(common_gcc_warning_flags)',
          '-Wno-non-virtual-dtor',
          '-Werror',
          '<@(common_gcc_cflags)',
          '-fno-rtti',
          '-fno-exceptions',
        ],
      },

      'fletch_release': {
        'abstract': 1,

        'defines': [
          'NDEBUG', # TODO(ahe): Is this necessary/used?
        ],

        'xcode_settings': { # And ninja.
          'OTHER_CPLUSPLUSFLAGS' : [
            '-O3',
            '-fomit-frame-pointer',
          ],
        },

        'cflags': [
          '-O3',
          '-fomit-frame-pointer',
        ],
      },

      'fletch_debug': {
        'abstract': 1,

        'defines': [
          'DEBUG',
        ],

        'xcode_settings': { # And ninja.
          'GCC_OPTIMIZATION_LEVEL': '0',

          'OTHER_CPLUSPLUSFLAGS': [
            '-g',
          ],
        },

        'cflags': [
          '-g',
          '-O0',
        ],
      },

      'fletch_ia32': {
        'abstract': 1,

        'defines': [
          'FLETCH32',
          'FLETCH_IA32',
        ],

        'cflags': [
          '-m32',
        ],

        'ldflags': [
          '-m32',
          '-L<(third_party_libs_path)/x86',
        ],

        'xcode_settings': { # And ninja.
          'ARCHS': [ 'i386' ],

          'LIBRARY_SEARCH_PATHS': [
            '<(third_party_libs_path)/x86',
          ],
        },
      },

      'fletch_x64': {
        'abstract': 1,

        'defines': [
          'FLETCH64',
          'FLETCH_X64',
        ],

        'ldflags': [
          '-L<(third_party_libs_path)/x64',
        ],

        'xcode_settings': { # And ninja.
          'ARCHS': [ 'x86_64' ],

          'LIBRARY_SEARCH_PATHS': [
            '<(third_party_libs_path)/x64',
          ],
        },
      },

      'fletch_arm': {
        'abstract': 1,

        'defines': [
          'FLETCH32',
          'FLETCH_ARM',
        ],

        'cflags': [
        ],

        'ldflags': [
          '-L<(third_party_libs_path)/arm',
          '-L/FLETCH_ARM',
        ],

        'xcode_settings': { # And ninja.
          'ARCHS': [ 'armv7' ],

          'LIBRARY_SEARCH_PATHS': [
            '<(third_party_libs_path)/arm',
          ],
        },
      },

      'fletch_asan': {
        'abstract': 1,

        'xcode_settings': { # And ninja.
          'OTHER_CPLUSPLUSFLAGS': [
            '-g3',
            '-fsanitize=address',
            '-fsanitize-undefined-trap-on-error',
          ],

          'OTHER_LDFLAGS': [
            # GYP's xcode_emulation for ninja passes OTHER_LDFLAGS to libtool,
            # which doesn't understand -fsanitize=address. The fake library
            # search path is recognized by cxx_wrapper.py and cc_wrapper.py,
            # which will pass the correct options to the linker.
            '-L/FLETCH_ASAN',
          ],
        },
      },

      'fletch_clang': {
        'abstract': 1,

        'defines': [
          # Recognized by cxx_wrapper.py and cc_wrapper.py and causes them to
          # invoke clang.
          'FLETCH_CLANG',
        ],

        'xcode_settings': { # And ninja.
          'OTHER_LDFLAGS': [
            # Recognized by cxx_wrapper.py and cc_wrapper.py and causes them to
            # invoke clang.
            '-L/FLETCH_CLANG',
          ],
        },
      },

      'ReleaseIA32': {
        'inherit_from': [ 'fletch_base', 'fletch_release', 'fletch_ia32' ],
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

      'DebugIA32': {
        'inherit_from': [ 'fletch_base', 'fletch_debug', 'fletch_ia32', ],
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
    },

    'target_conditions': [
      # Exclude sources that do not match the platform.
      ['OS!="mac"', {
        'sources/': [
          ['exclude', '_macos(_test)?\\.(h|cc|mm?)$' ], ],
      }],
      ['OS!="linux"', {
        'sources/': [
          ['exclude', '_linux(_test)?\\.(h|cc|mm?)$' ], ],
      }],
      ['OS!="linux" and OS!="mac"', {
        'sources/': [
          ['exclude', '_posix(_test)?\\.(h|cc|mm?)$' ], ],
      }],
    ],
  },
}
