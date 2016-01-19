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

    'common_gcc_cflags_c': [
      '-fdata-sections',
      '-ffunction-sections',
      '-fvisibility=hidden',
    ],

    'common_gcc_cflags_cc': [
      '-std=c++11',
      '<@(common_gcc_cflags_c)',
    ],

    'LK_PATH%': 'third_party/lk/lk-downstream',

    'LK_USE_DEPS_ARM_GCC%': '1',

    'mbed_path': '<(DEPTH)/third_party/mbed/build/',

    'posix%': 1,

    'conditions': [
      [ 'OS=="mac"', {
        # TODO(zerny): Redirect stderr to work around gyp regarding a non-empty
        # stderr as a failed command. This should be replaced by a custom script
        # that retains stderr in case the command actually fails.
        'ios_sdk_path%': '<!(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)',
        'ios_sim_sdk_path%':
            '<!(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null)',
      }],
    ],
  },

  'conditions': [
    [ 'OS!="win"', {
      'make_global_settings': [
        [ 'CC', 'tools/cc_wrapper.py' ],
        [ 'CXX', 'tools/cxx_wrapper.py' ],
        [ 'LINK', 'tools/cc_wrapper.py' ],
      ],
    }],
  ],

  'target_defaults': {
    'msvs_cygwin_dirs': ['<(DEPTH)/third_party/cygwin'],
    'msvs_cygwin_shell': 0,

    'configurations': {

      'fletch_base': {
        'abstract': 1,

        'defines': [
          'FLETCH_ENABLE_LIVE_CODING',
          'FLETCH_ENABLE_FFI',
          'FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS',
          'FLETCH_ENABLE_NATIVE_PROCESSES',
          'FLETCH_ENABLE_PRINT_INTERCEPTORS',
        ],

        'xcode_settings': {
          # Settings for Xcode and ninja. Huh? Yeah, GYP is awesome!

          'GCC_C_LANGUAGE_STANDARD': 'ansi',
          'GCC_TREAT_WARNINGS_AS_ERRORS': 'YES', # -Werror
          'GCC_WARN_NON_VIRTUAL_DESTRUCTOR': 'NO', # -Wno-non-virtual-dtor
          'GCC_ENABLE_CPP_RTTI': 'NO', # -fno-rtti
          'GCC_ENABLE_CPP_EXCEPTIONS': 'NO', # -fno-exceptions
          'DEAD_CODE_STRIPPING': 'YES', # -Wl,-dead_strip (mac --gc-sections)

          'OTHER_CPLUSPLUSFLAGS' : [
            '<@(common_gcc_cflags_cc)',
            '-stdlib=libc++',
          ],

          'WARNING_CFLAGS': [
            '<@(common_gcc_warning_flags)',
            '-Wtrigraphs', # Disable Xcode default.
          ],

          'OTHER_LDFLAGS': [
            '-framework CoreFoundation',
          ],
        },

        'cflags_cc': [
          '<@(common_gcc_warning_flags)',
          '-Wno-non-virtual-dtor',
          '-Werror',
          '<@(common_gcc_cflags_cc)',
          '-fno-rtti',
          '-fno-exceptions',
        ],

        'cflags_c': [
          '<@(common_gcc_warning_flags)',
          '-Werror',
          '<@(common_gcc_cflags_c)',
          '-fno-exceptions',
        ],

        'ldflags': [
          '-Wl,--gc-sections',
        ],

        'target_conditions': [
          ['OS=="mac"', {
            'defines': [
              'FLETCH_TARGET_OS_MACOS',
              'FLETCH_TARGET_OS_POSIX' ],
          }],
          ['OS=="linux"', {
            'defines': [
              'FLETCH_TARGET_OS_LINUX',
              'FLETCH_TARGET_OS_POSIX' ],
          }],
          ['OS=="win"', {
            'defines': [
              'FLETCH_TARGET_OS_WIN' ],
          }],
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
            # Strict aliasing optimizations are not safe for the
            # type of VM code that we write. We operate with
            # raw memory aliased with a mixture of pointer types.
            '-fno-strict-aliasing',
          ],
        },

        'cflags': [
          '-O3',
          '-fomit-frame-pointer',
            # Strict aliasing optimizations are not safe for the
            # type of VM code that we write. We operate with
            # raw memory aliased with a mixture of pointer types.
          '-fno-strict-aliasing',
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
          'FLETCH_TARGET_IA32',
        ],

        'cflags': [
          '-m32',
          # Forces GCC to not use x87 floating point instructions.
          '-mfpmath=sse',
          '-msse2',
        ],

        'ldflags': [
          '-m32',
        ],

        'xcode_settings': { # And ninja.
          'ARCHS': [ 'i386' ],
        },

        'yasm_flags': [
          '-fwin32',
          '-m', 'x86',
          '-p', 'gas',
        ],
      },

      'fletch_x64': {
        'abstract': 1,

        'defines': [
          'FLETCH64',
          'FLETCH_TARGET_X64',
        ],

        # Shared libraries on x64 require compilation with position
        # independent code. Load-time relocation is not supported on
        # x64. For simplicity we compile all x64 libraries with
        # position independent code.
        'cflags': ['-fPIC'],

        'xcode_settings': { # And ninja.
          'ARCHS': [ 'x86_64' ],

          'OTHER_CPLUSPLUSFLAGS': [
            '-fPIC',
          ],
        },

        'yasm_flags': [
          '-fwin64',
          '-m', 'amd64',
          '-p', 'gas',
        ],
      },

      'fletch_arm': {
        'abstract': 1,

        'defines': [
          'FLETCH32',
          'FLETCH_TARGET_ARM',
        ],

        'xcode_settings': { # And ninja.
          'ARCHS': [ 'armv7' ],
        },
      },

      'fletch_xarm': {
        'abstract': 1,

        'defines': [
          'FLETCH32',
          'FLETCH_TARGET_ARM',
        ],

        'target_conditions': [
          ['_toolset=="target"', {
            'conditions': [
              ['OS=="linux"', {
                'defines': [
                  # Fake define intercepted by cc_wrapper.py to change the
                  # compiler binary to an ARM cross compiler. This is only
                  # needed on linux.
                  'FLETCH_ARM',
                 ],
               }],
              ['OS=="mac"', {
                'xcode_settings': { # And ninja.
                  'ARCHS': [ 'armv7' ],

                  'OTHER_CPLUSPLUSFLAGS' : [
                    '-isysroot',
                    '<(ios_sdk_path)',
                  ],

                  'OTHER_CFLAGS' : [
                    '-isysroot',
                    '<(ios_sdk_path)',
                  ],
                },
               }]
            ],

            'ldflags': [
              # Fake define intercepted by cc_wrapper.py.
              '-L/FLETCH_ARM',
              '-static-libstdc++',
            ],
          }],

          ['_toolset=="host"', {
            # Compile host targets as IA32, to get same word size.
            'inherit_from': [ 'fletch_ia32' ],

            # The 'fletch_ia32' target will define IA32 as the target. Since
            # the host should still target ARM, undefine it.
            'defines!': [
              'FLETCH_TARGET_IA32',
            ],
          }],
        ],
      },

      'fletch_xarm64': {
        'abstract': 1,

        'defines': [
          'FLETCH64',
          'FLETCH_TARGET_ARM64',
        ],

        'target_conditions': [
          ['_toolset=="target"', {
            'conditions': [
              ['OS=="linux"', {
                'defines': [
                  # Fake define intercepted by cc_wrapper.py to change the
                  # compiler binary to an ARM64 cross compiler. This is only
                  # needed on linux.
                  'FLETCH_ARM64',
                 ],
               }],
              ['OS=="mac"', {
                'xcode_settings': { # And ninja.
                  'ARCHS': [ 'arm64' ],

                  'OTHER_CPLUSPLUSFLAGS' : [
                    '-isysroot',
                    '<(ios_sdk_path)',
                  ],

                  'OTHER_CFLAGS' : [
                    '-isysroot',
                    '<(ios_sdk_path)',
                  ],
                },
               }],
            ],

            'ldflags': [
              # Fake define intercepted by cc_wrapper.py.
              '-L/FLETCH_ARM64',
              '-static-libstdc++',
            ],
          }],

          ['_toolset=="host"', {
            # Compile host targets as X64, to get same word size.
            'inherit_from': [ 'fletch_x64' ],

            # The 'fletch_x64' target will define IA32 as the target. Since
            # the host should still target ARM, undefine it.
            'defines!': [
              'FLETCH_TARGET_X64',
            ],
          }],
        ],
      },

      'fletch_lk': {
        'abstract': 1,

        'defines': [
          'FLETCH32',
          'FLETCH_TARGET_ARM',
          'FLETCH_THUMB_ONLY',
        ],

        'target_conditions': [
          ['_toolset=="target"', {
            'defines': [
              'FLETCH_TARGET_OS_LK',
             ],
            'conditions': [
              ['LK_USE_DEPS_ARM_GCC==1', {
                'defines': [
                  'GCC_XARM_EMBEDDED', # Fake define for cc_wrapper.py.
                ],
                'ldflags': [
                  # Fake define intercepted by cc_wrapper.py.
                  '-L/GCC_XARM_EMBEDDED',
                ],
              }, { # 'LK_USE_DEPS_ARM_GCC!=1'
                'defines': [
                  'GCC_XARM_LOCAL', # Fake define for cc_wrapper.py.
                ],
                'ldflags': [
                  # Fake define intercepted by cc_wrapper.py.
                  '-L/GCC_XARM_LOCAL',
                ],
              }],
            ],
            'cflags': [
              '-mfloat-abi=softfp',
              '-mfpu=fpv4-sp-d16',
              '-mthumb',
              '-Wno-unused-function',
              '-Wno-error=multichar',
            ],

            'cflags_c': [
              '--std=c99',
            ],

            'cflags_cc': [
              '--std=c++11',
            ],

            'include_dirs': [
              '<(DEPTH)/<(LK_PATH)/../out',
              '<(DEPTH)/<(LK_PATH)/../../out',
              '<(DEPTH)/<(LK_PATH)/include/',
              '<(DEPTH)/<(LK_PATH)/arch/arm/include/',
              '<(DEPTH)/<(LK_PATH)/lib/libm/include/',
              '<(DEPTH)/<(LK_PATH)/lib/minip/include/',
              '<(DEPTH)/<(LK_PATH)/arch/arm/arm/include',
              '<(DEPTH)/<(LK_PATH)/lib/heap/include/',
            ],

            'defines!': [
              'FLETCH_TARGET_OS_MACOS',
              'FLETCH_TARGET_OS_LINUX',
              'FLETCH_TARGET_OS_POSIX',
            ],
          }],

          ['_toolset=="host"', {
            # Compile host targets as IA32, to get same word size.
            'inherit_from': [ 'fletch_ia32' ],

            # The 'fletch_ia32' target will define IA32 as the target. Since
            # the host should still target ARM, undefine it.
            'defines!': [
              'FLETCH_TARGET_IA32',
            ],
          }],
        ],
      },

      'fletch_mbed': {
        'abstract': 1,

        'defines': [
          'FLETCH32',
          'FLETCH_TARGET_ARM',
          'FLETCH_THUMB_ONLY',
        ],

        'target_conditions': [
          ['_toolset=="target"', {
            'defines': [
              'GCC_XARM_EMBEDDED', # Fake define intercepted by cc_wrapper.py.
              'FLETCH_TARGET_OS_CMSIS',
            ],

            'defines!': [
              'FLETCH_TARGET_OS_POSIX',
              'FLETCH_TARGET_OS_LINUX',
              'FLETCH_TARGET_OS_MACOS',
            ],

            'cflags': [
              '-mcpu=cortex-m4',
              '-mthumb',
              '-mfloat-abi=softfp',
              '-fno-common',
            ],

            # Use the gnu language dialect to get math.h constants
            'cflags_c': [
              '--std=gnu99',
            ],

            # Use the gnu language dialect to get math.h constants
            'cflags_cc': [
              '--std=gnu++11',
            ],

            'include_dirs': [
              '<(mbed_path)/rtos/TARGET_CORTEX_M',
            ],

            'ldflags': [
              '-L/GCC_XARM_EMBEDDED', # Fake define intercepted by cc_wrapper.py.
              '-static-libstdc++',
            ],
          }],

          ['_toolset=="host"', {
            # Compile host targets as IA32, to get same word size.
            'inherit_from': [ 'fletch_ia32' ],

            # Undefine IA32 target and using existing ARM target.
            'defines!': [
              'FLETCH_TARGET_IA32',
            ],
          }],
        ],
      },

      'fletch_asan': {
        'abstract': 1,

        'cflags': [
          '-fsanitize=address',
        ],

        'defines': [
          'FLETCH_ASAN',
        ],

        'ldflags': [
          '-fsanitize=address',
        ],

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

        'ldflags': [
          # The define above is not passed to the cxx_wrapper.py and
          # cc_wrapper.py scripts when linking. We therefore have to force
          # the use of clang with a dummy link flag.
          '-L/FLETCH_CLANG',
        ],

        'xcode_settings': { # And ninja.
          'OTHER_LDFLAGS': [
            # Recognized by cxx_wrapper.py and cc_wrapper.py and causes them to
            # invoke clang.
            '-L/FLETCH_CLANG',
          ],
        },
      },

      'fletch_ios_sim': {
        'abstract': 1,
        'conditions': [
          [ 'OS=="mac"', {
            'target_conditions': [
              ['_toolset=="target"', {
                'xcode_settings': {
                  'OTHER_CPLUSPLUSFLAGS' : [
                    '-isysroot',
                    '<(ios_sim_sdk_path)',
                    '-miphoneos-version-min=7.0',
                  ],
                  'OTHER_CFLAGS' : [
                    '-isysroot',
                    '<(ios_sim_sdk_path)',
                    '-miphoneos-version-min=7.0',
                  ],
                },
              }],
            ],
          }],
        ],
      },

      'fletch_disable_live_coding': {
        'abstract': 1,

        'defines!': [
          'FLETCH_ENABLE_LIVE_CODING',
        ],
      },

      'fletch_disable_ffi': {
        'abstract': 1,

        'defines!': [
          'FLETCH_ENABLE_FFI',
        ],
      },

      'fletch_disable_multiple_process_heaps': {
        'abstract': 1,

        'defines!': [
          'FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS',
        ],

        'defines': [
          'FLETCH_MARK_SWEEP',
        ],
      },

      'fletch_disable_native_processes': {
        'abstract': 1,

        'defines!': [
          'FLETCH_ENABLE_NATIVE_PROCESSES',
        ],
      },

      'fletch_disable_print_interceptors': {
        'abstract': 1,

        'defines!': [
          'FLETCH_ENABLE_PRINT_INTERCEPTORS',
        ],
      },
    },
  },
}
