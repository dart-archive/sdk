# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'target_defaults': {
    'include_dirs': [
      '<(stm32_cube_f7)/Drivers/CMSIS/Include/',
      '<(stm32_cube_f7)/Drivers/CMSIS/Device/ST/STM32F7xx/Include/',
      '<(stm32_cube_f7)/Drivers/BSP/STM32746G-Discovery/',
      '<(stm32_cube_f7)/Drivers/BSP/Components/Common/',
      '<(stm32_cube_f7)/Middlewares/ST/STemWin/Config/',
      '<(stm32_cube_f7)/Middlewares/ST/STemWin/inc/',
      '<(stm32_cube_f7)/Middlewares/ST/STM32_USB_Device_Library/Core/Inc/',
      '<(stm32_cube_f7)/Middlewares/ST/STM32_USB_Host_Library/Core/Inc/',
      '<(stm32_cube_f7)/Middlewares/ST/STM32_USB_Host_Library/Class/MSC/Inc/',
      '<(stm32_cube_f7)/Middlewares/Third_Party/FatFs/src/',
      '<(stm32_cube_f7)/Middlewares/Third_Party/FatFs/src/drivers/',
      '<(stm32_cube_f7)/Utilities/Log',
      '<(stm32_cube_f7)/Utilities/Fonts',
      '<(stm32_cube_f7)/Utilities/CPU',
    ],
  },
  'targets': [
    {
      'target_name': 'disco_fletch.elf',
      'variables': {
        'project_name': 'disco_fletch',
        'project_path': '<(DEPTH)/platforms/stm/<(project_name)',
        'source_path': '<(project_path)/src/',
        'generated_path': '<(project_path)/generated',
        'template_path': '<(project_path)/template/',
        'ldflags': [
          '-specs=nosys.specs',
          '-specs=nano.specs',
          # TODO(340): Why does this not work???
          #'-T<(generated_path)/SW4STM32/configuration/STM32F746NGHx_FLASH.ld',
          # TODO(340): Why is this needed???
          '-T../../platforms/stm/disco_fletch/generated/SW4STM32/'
            'configuration/STM32F746NGHx_FLASH.ld'
        ],
        'cflags': [
          '-Wno-write-strings'
        ],
      },
      'type': 'executable',
      'includes': [
        '../hal_sources.gypi',
        '../free_rtos_sources.gypi',
      ],
      'include_dirs': [
        '<(generated_path)/Inc',
        '<(source_path)',
      ],
      'sources': [
        # Application.
        '<(source_path)/fletch_entry.cc',

        # Generated files.
        '<(generated_path)/Src/main.c',
        '<(generated_path)/Src/freertos.c',
        '<(generated_path)/Src/stm32f7xx_hal_msp.c',
        '<(generated_path)/Src/stm32f7xx_it.c',

        # Board initialization and interrupt service routines (template files).
        '<(template_path)/system_stm32f7xx.c',
        '<(template_path)/startup_stm32f746xx.s',

        # Board support packages.
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_CFLAGS': [
              '<@(cflags)',
            ],
            'OTHER_CPLUSPLUSFLAGS' : [
              '<@(cflags)',
            ],
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
        ['OS=="linux"', {
          'cflags': [
            '<@(cflags)',
          ],
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
      ],
    },
    {
      'variables': {
        'project_name': 'disco_fletch',
      },
      'type': 'none',
      'target_name': 'disco_fletch',
      'dependencies' : [
        'disco_fletch.elf'
      ],
      'actions': [
        {
          'action_name': 'generate_bin',
          'inputs': [
            '<(PRODUCT_DIR)/<(project_name).elf',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/<(project_name).bin',
          ],
          'action': [
            '<(objcopy)',
            '-O',
            'binary',
            '<(PRODUCT_DIR)/<(project_name).elf',
            '<(PRODUCT_DIR)/<(project_name).bin',
          ],
        },
      ],
    },
    {
      'type': 'none',
      'target_name': 'disco_fletch_flash',
      'dependencies' : [
        'disco_fletch'
      ],
      'actions': [
        {
          'action_name': 'flash',
          'inputs': [
            '<(PRODUCT_DIR)/disco_fletch.bin',
          ],
          'outputs': [
            'dummy',
          ],
          'action': [
            '<(DEPTH)/tools/lk/flash-image.sh',
            '--disco',
            '<(PRODUCT_DIR)/disco_fletch.bin',
          ],
        },
      ],
    },
  ],
}
