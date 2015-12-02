# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'stm32_cube_f7': '<(DEPTH)/third_party/stm/STM32Cube_FW_F7_V1.2.0',
    'stm32_cube_f7_bsp_discovery':
      '<(stm32_cube_f7)/Drivers/BSP/STM32746G-Discovery/',
    'gcc-arm-embedded':
      '<(DEPTH)/third_party/gcc-arm-embedded/<(OS)/gcc-arm-embedded/bin',
    'objcopy': '<(gcc-arm-embedded)/arm-none-eabi-objcopy',

    # Common flags (C and C++) for the GCC ARM Embedded toolchain.
    'common_cross_gcc_cflags': [
      '-mcpu=cortex-m7',
      '-mthumb',
      '-mfloat-abi=hard',
      '-mfpu=fpv5-sp-d16',
      '-Os',
      '-Wall',
      '-fmessage-length=0',
      '-ffunction-sections',
    ],

    # Common release mode flags (C and C++) for the GCC ARM Embedded toolchain.
    'common_cross_gcc_release_cflags': [
      '-g0',
    ],

    # Common debug mode flags (C and C++) for the GCC ARM Embedded toolchain.
    'common_cross_gcc_debug_cflags': [
      '-g3',
    ],

    # Use the gnu language dialect to get math.h constants
    'common_cross_gcc_cflags_c': [
      '--std=gnu99',
    ],

    # Use the gnu language dialect to get math.h constants
    'common_cross_gcc_cflags_cc': [
      '-std=c++11',
    ],

    # Common linker flags for the GCC ARM Embedded toolchain.
    'common_cross_gcc_ldflags': [
      '-mcpu=cortex-m7',
      '-mthumb',
      '-mfloat-abi=hard',
      '-mfpu=fpv5-sp-d16',
      '-Wl,-Map=output.map',
      '-Wl,--gc-sections',
      '-L/GCC_XARM_EMBEDDED', # Fake define intercepted by cc_wrapper.py.
    ],
  },

  'includes': [
    '../../common.gypi'
  ],

  'target_defaults': {
    'configurations': {
      'fletch_stm': {
        'abstract': 1,

        'target_conditions': [
          ['_toolset=="target"', {
            'defines': [
              'GCC_XARM_EMBEDDED', # Fake define intercepted by cc_wrapper.py.

              'USE_HAL_DRIVER',
              'STM32F746xx',
              'USE_STM32746G_DISCOVERY',
              'USE_STM32746G_DISCO',
            ],
            'conditions': [
              ['OS=="mac"', {
                'xcode_settings': {
                  # This removes the option -fasm-blocks that GCC ARM Embedded
                  # does not support.
                  'GCC_CW_ASM_SYNTAX': 'NO',
                  # This removes the option -gdwarf-2'.
                  # TODO(sgjesse): Revisit debug symbol generation.
                  'GCC_GENERATE_DEBUGGING_SYMBOLS': 'NO',
                  'OTHER_CFLAGS': [
                    '<@(common_cross_gcc_cflags)',
                    '<@(common_cross_gcc_cflags_c)',
                  ],
                  'OTHER_CPLUSPLUSFLAGS' : [
                    '<@(common_cross_gcc_cflags)',
                    '<@(common_cross_gcc_cflags_cc)',
                  ],

                  'OTHER_LDFLAGS': [
                    '<@(common_cross_gcc_ldflags)',
                  ],
                },
              }],
              ['OS=="linux"', {
                'cflags': [
                  '<@(common_cross_gcc_cflags)',
                ],
                'cflags_c': [
                  '<@(common_cross_gcc_cflags_c)',
                ],
                'cflags_cc': [
                  '<@(common_cross_gcc_cflags_cc)',
                ],
                'ldflags': [
                  '<@(common_cross_gcc_ldflags)',
                ],
              }],
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

      'ReleaseSTM': {
        'inherit_from': [
          'fletch_stm'
        ],
        'target_conditions': [
          ['_toolset=="target"', {
            'conditions': [
              ['OS=="mac"', {
                'xcode_settings': {
                  'OTHER_CFLAGS': [
                    '<@(common_cross_gcc_release_cflags)',
                  ],
                  'OTHER_CPLUSPLUSFLAGS' : [
                  '<@(common_cross_gcc_release_cflags)',
                  ],
                },
              }],
              ['OS=="linux"', {
                'cflags': [
                  '<@(common_cross_gcc_release_cflags)',
                ],
              }],
            ],
          }],
        ],
      },

      'DebugSTM': {
        'inherit_from': [
          'fletch_stm'
        ],
        'target_conditions': [
          ['_toolset=="target"', {
            'conditions': [
              ['OS=="mac"', {
                'xcode_settings': {
                  'OTHER_CFLAGS': [
                    '<@(common_cross_gcc_debug_cflags)',
                  ],
                  'OTHER_CPLUSPLUSFLAGS' : [
                  '<@(common_cross_gcc_debug_cflags)',
                  ],
                },
              }],
              ['OS=="linux"', {
                'cflags': [
                  '<@(common_cross_gcc_debug_cflags)',
                ],
              }],
            ],
          }],
        ],
      },
    },
  },
}
