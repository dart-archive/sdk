# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
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
      'type': 'none',
      'target_name': 'disco_dartino_dart_snapshot',
      'variables': {
        'source_path': 'src',
      },
      'actions': [
        {
          'action_name': 'generate_snapshot',
          'inputs': [
            'src/test.dart',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/snapshot',
          ],
          'action': [
            '<(PRODUCT_DIR)/../ReleaseX64/dartino',
            'export',
            '<(source_path)/test.dart',
            'to',
            'file',
            '<(PRODUCT_DIR)/snapshot',
          ],
        },
      ],
    },
    {
      'type': 'none',
      'target_name': 'disco_dartino_dart_program.S',
      'dependencies' : [
        'disco_dartino_dart_snapshot',
      ],
      'actions': [
        {
          'action_name': 'flashify_program',
          'inputs': [
            '<(PRODUCT_DIR)/snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/program.S',
          ],
          'action': [
            '<(PRODUCT_DIR)/../ReleaseIA32/dartino-flashify',
            '<(PRODUCT_DIR)/snapshot',
            '<(PRODUCT_DIR)/program.S',
          ],
        },
      ],
    },
    {
      'type': 'none',
      'target_name': 'disco_dartino_dart_program.o',
      'dependencies' : [
        'disco_dartino_dart_program.S',
      ],
      'actions': [
        {
          'action_name': 'linkify_program',
          'inputs': [
            '<(PRODUCT_DIR)/program.S',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/program.o',
          ],
          'action': [
            '../../../third_party/gcc-arm-embedded/linux/'
                'gcc-arm-embedded/bin/arm-none-eabi-gcc',
            '-mcpu=cortex-m7',
            '-mthumb',
            '-o',
            '<(PRODUCT_DIR)/program.o',
            '-c',
            '<(PRODUCT_DIR)/program.S',
          ],
        },
      ],
    },
    {
      'target_name': 'libdisco_dartino',
      'variables': {
        'source_path': 'src',
        'generated_path': 'generated',
        'template_path': 'template',
        'common_cflags': [
          # Our target will link in the stm files which do have a few warnings.
          '-Wno-write-strings',
          '-Wno-sign-compare',
          '-Wno-missing-field-initializers',
        ],
        'common_cflags_cc': [
          '-Wno-literal-suffix',
        ],
      },
      'type': 'static_library',
      'standalone_static_library': 1,
      'includes': [
        '../free_rtos_sources.gypi',
        '../hal_sources.gypi',
      ],
      'defines': [
        'DATA_IN_ExtSDRAM',  # Avoid BSP_LDC_Init initializing SDRAM.
      ],
      'include_dirs': [
        '<(generated_path)/Inc',
        '<(source_path)',
      ],
      'sources': [
        # Application.
        '<(source_path)/button.cc',
        '<(source_path)/button.h',
        '<(source_path)/circular_buffer.cc',
        '<(source_path)/circular_buffer.h',
        '<(source_path)/cmpctmalloc.c',
        '<(source_path)/cmpctmalloc.h',
        '<(source_path)/device_manager.h',
        '<(source_path)/device_manager.cc',
        '<(source_path)/freertos.cc',
        '<(source_path)/FreeRTOSConfig.h',
        '<(source_path)/dartino_entry.cc',
        '<(source_path)/main.cc',
        '<(source_path)/page_allocator.cc',
        '<(source_path)/page_allocator.h',
        '<(source_path)/uart.cc',
        '<(source_path)/uart.h',

        '<(source_path)/syscalls.c',

        '<(source_path)/exceptions.c',

        # Generated files.
        '<(generated_path)/Inc/mxconstants.h',
        '<(generated_path)/Inc/stm32f7xx_hal_conf.h',
        '<(generated_path)/Inc/stm32f7xx_it.h',
        '<(generated_path)/Src/mx_init.c',  # Derived from generated main.c.
        '<(generated_path)/Src/stm32f7xx_hal_msp.c',
        '<(generated_path)/Src/stm32f7xx_it.c',

        # Board initialization and interrupt service routines (template files).
        '<(template_path)/system_stm32f7xx.c',
        '<(template_path)/startup_stm32f746xx.s',

       # Board support packages.
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_lcd.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_sdram.c',

        # Additional utilities.
        '<(stm32_cube_f7)/Utilities/Log/lcd_log.c',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_CFLAGS': [
              '<@(common_cflags)',
            ],
            'OTHER_CPLUSPLUSFLAGS' : [
              '<@(common_cflags)',
              '<@(common_cflags_cc)',
            ],
          },
        }],
        ['OS=="linux"', {
          'cflags': [
            '<@(common_cflags)',
          ],
          'cflags_cc': [
            '<@(common_cflags_cc)',
          ],
        }],
      ],
    },
    {
      'target_name': 'disco_dartino.elf',
      'dependencies': [
        'libdisco_dartino',
        'disco_dartino_dart_program.o',
        '../../../src/vm/vm.gyp:libdartino',
      ],
      'variables': {
        'common_ldflags': [
          '-specs=nano.specs',
          '-specs=nosys.specs',
          # TODO(340): Why does this not work???
          #'-T<(generated_path)/SW4STM32/configuration/STM32F746NGHx_FLASH.ld',
          # TODO(340): Why is this needed???
          '-T../../platforms/stm/disco_dartino/generated/SW4STM32/'
            'configuration/STM32F746NGHx_FLASH.ld',
          '-Wl,--wrap=__libc_init_array',
          '-Wl,--wrap=_malloc_r',
          '-Wl,--wrap=_malloc_r',
          '-Wl,--wrap=_realloc_r',
          '-Wl,--wrap=_calloc_r',
          '-Wl,--wrap=_free_r',
        ],
      },
      'type': 'executable',
      'sources': [
        '<(PRODUCT_DIR)/program.o',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '<@(common_ldflags)',
            ],
          },
        }],
        ['OS=="linux"', {
          'ldflags': [
            '<@(common_ldflags)',
          ],
        }],
      ],
      'libraries': [
        '-lstdc++',
      ],
    },
    {
      'variables': {
        'project_name': 'disco_dartino',
      },
      'type': 'none',
      'target_name': 'disco_dartino',
      'dependencies' : [
        'disco_dartino.elf'
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
      'target_name': 'disco_dartino_flash',
      'dependencies' : [
        'disco_dartino'
      ],
      'actions': [
        {
          'action_name': 'flash',
          'inputs': [
            '<(PRODUCT_DIR)/disco_dartino.bin',
          ],
          'outputs': [
            'dummy',
          ],
          'action': [
            '<(DEPTH)/tools/lk/flash-image.sh',
            '--disco',
            '<(PRODUCT_DIR)/disco_dartino.bin',
          ],
        },
      ],
    },
  ],
}
