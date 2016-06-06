# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'posix': 0,

    'freertos_with_labs': '<(DEPTH)/third_party/freertos/',
    'stm32_cube_f4': '<(DEPTH)/third_party/stm/stm32cube_fw_f4',
    'freertos': '<(stm32_cube_f4)/Middlewares/Third_Party/FreeRTOS',
    'freertos_port': 'ARM_CM3',
    'stm32_cube_f4_bsp_discovery':
      '<(stm32_cube_f4)/Drivers/BSP/STM32F4-Discovery/',
    'stm32_cube_f4_bsp_nucleo':
      '<(stm32_cube_f4)/Drivers/BSP/STM32F4xx-Nucleo/',

    'gcc-arm-embedded':
      '<(DEPTH)/third_party/gcc-arm-embedded/<(OS)/gcc-arm-embedded/bin',
    'objcopy': '<(gcc-arm-embedded)/arm-none-eabi-objcopy',
  },

  'includes': [
    '../../common.gypi'
  ],

  'target_defaults': {
    'configurations': {
      'dartino_stm': {
        'abstract': 1,

        'target_conditions': [
          ['_toolset=="target"', {
            'defines': [
              'USE_HAL_DRIVER',
            ],
            'include_dirs': [
              # We need to set these here since the src/shared/platform_cmsis.h
              # includes cmsis_os.h from here.
              '<(freertos)/Source/CMSIS_RTOS/',
              '<(freertos)/Source/include/',
              '<(freertos)/Source/portable/GCC/<(freertos_port)/',
              '<(stm32_cube_f4)/Drivers/CMSIS/Include/',
              # For FreeRTOSConfig.h.
              'disco_dartino/src',
              # The include directory in the root.
              '../..'
            ],
          }],
        ],
      },

      'ReleaseCM4': {
        'inherit_from': [
          'dartino_base', 'dartino_release',
          # Use the Cortex M3 flags for Cortex M4 without FPU.
          'dartino_cortex_m_base', 'dartino_cortex_m3', 'dartino_stm',
          'dartino_disable_live_coding',
          'dartino_disable_native_processes',
        ],
        'target_conditions': [
          # Change to optimize for size.
          ['_toolset=="target"', {
            'cflags!': [
              '-O3',
            ],
            'cflags': [
              '-Os',
            ],
          }],
        ],
      },

      'DebugCM4': {
        'inherit_from': [
          'dartino_base', 'dartino_debug',
          # Use the Cortex M3 flags for Cortex M4 without FPU.
          'dartino_cortex_m_base', 'dartino_cortex_m3', 'dartino_stm',
          'dartino_disable_live_coding',
          'dartino_disable_native_processes',
        ],
      },

      'ReleaseCM4F': {
        'inherit_from': [
          'dartino_base', 'dartino_debug',
          'dartino_cortex_m_base', 'dartino_cortex_m4f', 'dartino_stm',
          'dartino_disable_live_coding',
          'dartino_disable_native_processes',
        ],
        'target_conditions': [
          # Change to optimize for size.
          ['_toolset=="target"', {
            'cflags!': [
              '-O3',
            ],
            'cflags': [
              '-Os',
            ],
          }],
        ],
      },

      'DebugCM4F': {
        'inherit_from': [
          'dartino_base', 'dartino_debug',
          'dartino_cortex_m_base', 'dartino_cortex_m4f', 'dartino_stm',
          'dartino_disable_live_coding',
          'dartino_disable_native_processes',
        ],
      },
    },
  },
}
