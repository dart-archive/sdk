# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'stm32_cube_f7': '<(DEPTH)/third_party/stm/STM32Cube_FW_F7_V1.2.0',
    'stm32_cube_f7_bsp_discovery':
      '<(stm32_cube_f7)/Drivers/BSP/STM32746G-Discovery/',
    'gcc-arm-embedded':
      '<(DEPTH)/third_party/gcc-arm-embedded/linux/gcc-arm-embedded/bin',
    'objcopy': '<(gcc-arm-embedded)/arm-none-eabi-objcopy',
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
              'USE_STM32746G_DISCOVERY'
              'USE_STM32746G_DISCO',
            ],

            'cflags': [
              '-mcpu=cortex-m7',
              '-mthumb',
              '-mfloat-abi=hard',
              '-mfpu=fpv5-sp-d16',
              '-Os',
              '-Wall',
              '-fmessage-length=0',
              '-ffunction-sections',
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
            ],

            'ldflags': [
              '-mcpu=cortex-m7',
              '-mthumb',
              '-mfloat-abi=hard',
              '-mfpu=fpv5-sp-d16',
              '-Wl,-Map=output.map',
              '-Wl,--gc-sections',
              '-L/GCC_XARM_EMBEDDED', # Fake define intercepted by cc_wrapper.py.
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
            'cflags': [
              '-g0',
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
            'cflags': [
              '-g3',
            ],
          }],
        ],
      },
    },
  },
}
