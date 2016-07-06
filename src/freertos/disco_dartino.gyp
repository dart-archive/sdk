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
      '<(stm32_cube_f7)/Drivers/BSP/Components/ft5336/',
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
      'target_name': 'libstm32f746g-discovery',
      'dependencies': [
        '../../src/pkg/mbedtls/mbedtls_static.gyp:mbedtls',
      ],
      'variables': {
        'source_path': 'stm32f746g-discovery',
        'generated_path': '<(source_path)/generated',
        'template_path': '<(source_path)/template',
        'common_cflags': [
          # Our target will link in the stm files which do have a few warnings.
          '-Wno-write-strings',
          '-Wno-sign-compare',
          '-Wno-missing-field-initializers',
        ],
        'common_cflags_cc': [
          '-Wno-literal-suffix',
        ],
        'freertos_plus_tcp':
          '<(freertos_with_labs)/freertos_labs/FreeRTOS-Plus/Source/'
              'FreeRTOS-Plus-TCP/',
      },
      'type': 'static_library',
      'standalone_static_library': 1,
      'includes': [
        'hal_sources.gypi',
      ],
      'defines': [
        'DATA_IN_ExtSDRAM',  # Avoid BSP_LDC_Init initializing SDRAM.
      ],
      'defines': [
        'STM32F746xx',
      ],
      'include_dirs': [
        '<(generated_path)',
        '<(source_path)',
        '<(freertos_plus_tcp)/include',
        '<(freertos_plus_tcp)/portable/Compiler/GCC/',
        '<(mbedtls)/include',
      ],
      'sources': [
        # Board initialization.
        '<(source_path)/board.c',

        # Device drivers.
        '<(source_path)/button_driver.cc',
        '<(source_path)/button_driver.h',
        '<(source_path)/i2c_driver.cc',
        '<(source_path)/i2c_driver.h',
        '<(source_path)/uart_driver.cc',
        '<(source_path)/uart_driver.h',

        # Network driver.
        '<(source_path)/network_interface.c',
        '<(source_path)/ethernet.cc',
        '<(source_path)/ethernet.h',
        '<(source_path)/socket.cc',
        '<(source_path)/socket.h',

        # Generated files.
        '<(generated_path)/mxconstants.h',
        '<(generated_path)/stm32f7xx_hal_conf.h',
        '<(generated_path)/stm32f7xx_it.h',
        '<(generated_path)/mx_init.c',  # Derived from generated main.c.
        '<(generated_path)/stm32f7xx_hal_msp.c',
        '<(generated_path)/stm32f7xx_it.c',

        # Board initialization and interrupt service routines (template files).
        '<(template_path)/system_stm32f7xx.c',
        '<(template_path)/startup_stm32f746xx.s',

       # Board support packages.
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_lcd.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_sdram.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_ts.c',

        # Additional utilities.
        '<(stm32_cube_f7)/Drivers/BSP/Components/ft5336/ft5336.c',
        '<(stm32_cube_f7)/Utilities/Log/lcd_log.c',
      ],
      'conditions': [
        ['OS=="linux"', {
          'cflags': [
            '<@(common_cflags)',
          ],
          'cflags_cc': [
            '<@(common_cflags_cc)',
          ],
        }],
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
      ],
    },
    {
      'target_name': 'disco_dartino.elf',
      'dependencies': [
        'freertos_dartino.gyp:libfreertos_dartino',
        'libstm32f746g-discovery',
        'freertos_dartino.gyp:disco_dartino_dart_program.o',
        '../vm/vm.gyp:libdartino',
      ],
      'variables': {
        'common_ldflags': [
          '-specs=nano.specs',
          # Without this, the weak and strong symbols for the IRQ handlers are
          # not linked correctly and you get the weak fallback versions that
          # loop forever instead of the IRQ handler you want for your hardware.
          '-Wl,--whole-archive',
          # TODO(340): Why does this not work???
          #'-T<(source_path)/STM32F746NGHx_FLASH.ld',
          # TODO(340): Why is this needed???
          '-T../../platforms/stm32f746g-discovery/stm32f746nghx-flash.ld',
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
        'embedder_options.c',
        '<(PRODUCT_DIR)/program.o',
      ],
      'conditions': [
        ['OS=="linux"', {
          'ldflags': [
            '<@(common_ldflags)',
          ],
        }],
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '<@(common_ldflags)',
            ],
          },
        }],
      ],
      'libraries': [
        # This option ends up near the end of the linker command, so that
        # --whole-archive (see above) is not applied to libstdc++ and the
        # implict libgcc.a library.
        '-Wl,--no-whole-archive',
        '-lstdc++',
      ],
    },
    {
      'variables': {
        'project_name': 'disco_dartino',
      },
      'type': 'none',
      'target_name': 'disco_746_dartino',
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
        'disco_746_dartino'
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
            '<(DEPTH)/tools/embedded/flash-image.sh',
            '--disco',
            '<(PRODUCT_DIR)/disco_dartino.bin',
          ],
        },
      ],
    },
  ],
}
