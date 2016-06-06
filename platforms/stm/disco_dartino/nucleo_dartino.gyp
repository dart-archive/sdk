# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'target_defaults': {
    'include_dirs': [
      '<(stm32_cube_f4)/Drivers/CMSIS/Device/ST/STM32F4xx/Include/',
    ],
  },
  'targets': [
    {
      'type': 'none',
      'target_name': 'disco_dartino_blinky_snapshot',
      'variables': {
        'source_path': 'src',
      },
      'actions': [
        {
          'action_name': 'generate_snapshot',
          'inputs': [
            '<(source_path)/blinky.dart',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/blinky.snapshot',
          ],
          'action': [
            '<(PRODUCT_DIR)/../ReleaseX64/dartino',
            'export',
            '<(source_path)/blinky.dart',
            'to',
            'file',
            '<(PRODUCT_DIR)/blinky.snapshot',
          ],
        },
      ],
    },
    {
      'type': 'none',
      'target_name': 'disco_dartino_blinky_program.S',
      'dependencies' : [
        'disco_dartino_blinky_snapshot',
      ],
      'actions': [
        {
          'action_name': 'flashify_program',
          'inputs': [
            '<(PRODUCT_DIR)/blinky.snapshot',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/blinky.S',
          ],
          'action': [
            '<(PRODUCT_DIR)/../ReleaseIA32/dartino-flashify',
            '<(PRODUCT_DIR)/blinky.snapshot',
            '<(PRODUCT_DIR)/blinky.S',
          ],
        },
      ],
    },
    {
      'type': 'none',
      'target_name': 'disco_dartino_blinky_program.o',
      'dependencies' : [
        'disco_dartino_blinky_program.S',
      ],
      'actions': [
        {
          'action_name': 'linkify_program',
          'inputs': [
            '<(PRODUCT_DIR)/blinky.S',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/blinky.o',
          ],
          'action': [
            '../../../third_party/gcc-arm-embedded/<(OS)/'
                'gcc-arm-embedded/bin/arm-none-eabi-gcc',
            '-mcpu=cortex-m3',
            '-mthumb',
            '-mfloat-abi=soft',
            '-o',
            '<(PRODUCT_DIR)/blinky.o',
            '-c',
            '<(PRODUCT_DIR)/blinky.S',
          ],
        },
      ],
    },

    {
      'target_name': 'libstm32f411xe-nucleo',
      'variables': {
        'source_path': 'src/stm32f411xe-nucleo',
        'template_path': '<(stm32_cube_f4)/Projects/STM32F411RE-Nucleo/Templates/',
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
        '../stm32f4_hal_sources.gypi',
      ],
      'defines': [
        'STM32F411xE',
        'USE_STM32F4XX_NUCLEO',
      ],
      'include_dirs': [
       '<(source_path)',
       # For stm32f4xx_hal_conf.h,
       '<(template_path)/Inc',
      ],
      'sources': [
        # Board initialization.
        '<(source_path)/board.c',

        # Board initialization and interrupt service routines (template files).
        '<(template_path)/Src/system_stm32f4xx.c',
        '<(template_path)/SW4STM32/startup_stm32f411xe.s',
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
      'target_name': 'nucleo_dartino.elf',
      'dependencies': [
        'freertos_dartino.gyp:libfreertos_dartino',
        'libstm32f411xe-nucleo',
        'disco_dartino_blinky_program.o',
        '../../../src/vm/vm.gyp:libdartino',
      ],
      'variables': {
        'common_ldflags': [
          '-specs=nano.specs',
          # Without this, the weak and strong symbols for the IRQ handlers are
          # not linked correctly and you get the weak fallback versions that
          # loop forever instead of the IRQ handler you want for your hardware.
          '-Wl,--whole-archive',
          # TODO(340): Why does this not work???
          #'-T<(generated_path)/SW4STM32/configuration/STM32F746NGHx_FLASH.ld',
          # TODO(340): Why is this needed???
          '-T../../platforms/stm32f411re-nucleo/stm32f411retx-flash.ld',
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
        'src/embedder_options.c',
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
        'project_name': 'nucleo_dartino',
      },
      'type': 'none',
      'target_name': 'nucleo_dartino',
      'dependencies' : [
        'nucleo_dartino.elf'
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
      'target_name': 'nucleo_dartino_flash',
      'dependencies' : [
        'nucleo_dartino'
      ],
      'actions': [
        {
          'action_name': 'flash',
          'inputs': [
            '<(PRODUCT_DIR)/nucleo_dartino.bin',
          ],
          'outputs': [
            'dummy',
          ],
          'action': [
            '<(DEPTH)/tools/lk/flash-image.sh',
            '--nucleo',
            '<(PRODUCT_DIR)/nucleo_dartino.bin',
          ],
        },
      ],
    },
  ],
}
