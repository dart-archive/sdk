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
      'target_name': 'event_handler_test_snapshot',
      'variables': {
        'source_path': 'src',
      },
      'actions': [
        {
          'action_name': 'event_handler_test_snapshot',
          'inputs': [
            '<(source_path)/test.dart',
          ],
          'outputs': [
            # This must be in CWD for the objcopy below to generate the
            # correct symbol names.
            '<(PRODUCT_DIR)/event_handler_test_snapshot',
          ],
          'action': [
            '<(PRODUCT_DIR)/../ReleaseX64/dartino',
            'export',
            '<(source_path)/test.dart',
            'to',
            'file',
            '<(PRODUCT_DIR)/event_handler_test_snapshot',
          ],
        },
      ],
    },
    {
      'type': 'none',
      'target_name': 'event_handler_test_snapshot.o',
      'dependencies' : [
        'event_handler_test_snapshot',
      ],
      'actions': [
        {
          'action_name': 'event_handler_test_snapshot',
          'inputs': [
            '<(PRODUCT_DIR)/event_handler_test_snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/event_handler_test_snapshot.o',
          ],
          'action': [
            'python',
            '../../../tools/run_with_cwd.py',
            '<(PRODUCT_DIR)',
            # As we are messing with CWD we need the path relative to
            # PRODUCT_DIR (where we cd into) instead of relative to
            # where this .gyp file is.
            '../../third_party/gcc-arm-embedded/<(OS)/'
                'gcc-arm-embedded/bin/arm-none-eabi-objcopy',
            '-I',
            'binary',
            '-O',
            'elf32-littlearm',
            '-B',
            'arm',
            'event_handler_test_snapshot',
            'event_handler_test_snapshot.o',
          ],
        },
      ],
    },
    {
      'target_name': 'libevent_handler_test',
      'variables': {
        'app_source_path': 'src',
        'source_path': '../disco_dartino/src',
        'generated_path': '../disco_dartino/generated',
        'template_path': '../disco_dartino/template',
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
      'includes': [
        '../free_rtos_sources.gypi',
        '../hal_sources.gypi',
      ],
      'include_dirs': [
        '<(generated_path)/Inc',
        '<(source_path)',
      ],
      'sources': [
        # Application.
        '<(source_path)/cmpctmalloc.c',
        '<(source_path)/cmpctmalloc.h',
        '<(source_path)/freertos.cc',
        '<(app_source_path)/dartino_entry.cc',
        '<(source_path)/main.cc',
        '<(source_path)/device_manager.cc',
        '<(source_path)/device_manager.h',
        '<(source_path)/page_allocator.cc',
        '<(source_path)/page_allocator.h',

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
      'target_name': 'event_handler_test.elf',
      'dependencies': [
        'libevent_handler_test',
        'event_handler_test_snapshot.o',
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
        '<(PRODUCT_DIR)/event_handler_test_snapshot.o',
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
        'project_name': 'event_handler_test',
      },
      'type': 'none',
      'target_name': 'event_handler_test',
      'dependencies' : [
        'event_handler_test.elf'
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
      'target_name': 'event_handler_test_flash',
      'dependencies' : [
        'event_handler_test'
      ],
      'actions': [
        {
          'action_name': 'flash',
          'inputs': [
            '<(PRODUCT_DIR)/event_handler_test.bin',
          ],
          'outputs': [
            'dummy',
          ],
          'action': [
            '<(DEPTH)/tools/lk/flash-image.sh',
            '--disco',
            '<(PRODUCT_DIR)/event_handler_test.bin',
          ],
        },
      ],
    },
  ],
}
