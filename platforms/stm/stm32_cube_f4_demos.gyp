# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'additional_gcc_warning_flags' : [
      '-Wno-missing-field-initializers',
      '-Wno-sign-compare',
      '-Wno-unused-but-set-variable',
    ],
  },

  'targets': [
    {
      'target_name': 'stm32f4_discovery_demonstrations.elf',
      'variables': {
        'project_path':
          '<(stm32_cube_f4)/Projects/STM32F4-Discovery/Demonstrations',
        'project_include_path': '<(project_path)/Inc/',
        'project_source_path': '<(project_path)/Src/',
        'ldflags': [
          '-specs=nosys.specs',
          '-specs=nano.specs',
          '-T<(project_path)/SW4STM32/STM32F4-DISCO/STM32F407VGTx_FLASH.ld',
        ],
      },
      'type': 'executable',
      'includes': [
        'stm32f4_hal_sources.gypi',
      ],
      'include_dirs': [
        '<(stm32_cube_f4)/Drivers/CMSIS/Device/ST/STM32F4xx/Include/',
        '<(stm32_cube_f4)/Drivers/BSP/STM32F4-Discovery/',
        '<(stm32_cube_f4)/Middlewares/ST/STM32_USB_Device_Library/Core/Inc',
        '<(stm32_cube_f4)/Middlewares/ST/'
            'STM32_USB_Device_Library/Class/HID/Inc/',
        '<(project_include_path)',
      ],
      'defines': [
        'STM32F407xx',
        'USE_STM32F4XX_NUCLEO',
      ],
      'sources': [
        # Application.
        '<(project_source_path)/main.c',
        '<(project_source_path)/stm32f4xx_hal_msp.c',
        '<(project_source_path)/usbd_conf.c',
        '<(project_source_path)/usbd_desc.c',

        # Board initialization and interrupt service routines.
        '<(project_source_path)/stm32f4xx_it.c',
        '<(project_source_path)/system_stm32f4xx.c',
        '<(project_path)/SW4STM32/startup_stm32f407xx.s',

        # Board support packages.
        '<(stm32_cube_f4_bsp_discovery)/stm32f4_discovery.c',

        # Drivers.
        '<(stm32_cube_f4)/Drivers/BSP/Components/lis302dl/lis302dl.c',
        '<(stm32_cube_f4)/Drivers/BSP/Components/lis3dsh/lis3dsh.c',
        '<(stm32_cube_f4)/Drivers/BSP/STM32F4-Discovery/'
            'stm32f4_discovery_accelerometer.c',
        '<(stm32_cube_f4)/Middlewares/ST/STM32_USB_Device_Library/Core/Src/'
            'usbd_core.c',
        '<(stm32_cube_f4)/Middlewares/ST/STM32_USB_Device_Library/Core/Src/'
            'usbd_ctlreq.c',
        '<(stm32_cube_f4)/Middlewares/ST/STM32_USB_Device_Library/Core/Src/'
            'usbd_ioreq.c',
        '<(stm32_cube_f4)/Middlewares/ST/STM32_USB_Device_Library/Class/HID/Src/'
            'usbd_hid.c',
      ],
      'conditions': [
        ['OS=="linux"', {
          'cflags': [
            '<@(additional_gcc_warning_flags)',
          ],
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_CFLAGS' : [
              '<@(additional_gcc_warning_flags)',
            ],
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
      ],
    },
    {
      'variables': {
        'project_name': 'stm32f4_discovery_demonstrations',
      },
      'type': 'none',
      'target_name': 'stm32f4_discovery_demonstrations',
      'dependencies' : [
        'stm32f4_discovery_demonstrations.elf'
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
      'target_name': 'stm32f411re_nucleo_demonstrations.elf',
      'variables': {
        'project_name': 'stm32f411re_nucleo_demonstrations',
        'project_path':
          '<(stm32_cube_f4)/Projects/STM32F411RE-Nucleo/Demonstrations',
        'project_include_path': '<(project_path)/Inc/',
        'project_source_path': '<(project_path)/Src/',
        'ldflags': [
          '-specs=nosys.specs',
          '-specs=nano.specs',
          '-T<(project_path)/SW4STM32/STM32F4xx_Nucleo/STM32F411RETx_FLASH.ld',
        ],
      },
      'type': 'executable',
      'includes': [
        'stm32f4_hal_sources.gypi',
      ],
      'include_dirs': [
        '<(stm32_cube_f4)/Drivers/CMSIS/Device/ST/STM32F4xx/Include/',
        '<(stm32_cube_f4)/Drivers/BSP/STM32F4xx-Nucleo/',
        '<(stm32_cube_f4)/Drivers/BSP/Adafruit_Shield/',
        '<(stm32_cube_f4)/Middlewares/Third_Party/FatFs/src',
        '<(stm32_cube_f4)/Middlewares/Third_Party/FatFs/src/drivers/',
        '<(project_include_path)',
      ],
      'defines': [
        'STM32F411xE',
        'USE_STM32F4XX_NUCLEO',
      ],
      'sources': [
        # Application.
        '<(project_source_path)/main.c',
        '<(project_source_path)/fatfs_storage.c',

        # Board initialization and interrupt service routines.
        '<(project_source_path)/stm32f4xx_it.c',
        '<(project_source_path)/system_stm32f4xx.c',
        '<(project_path)/SW4STM32/startup_stm32f411xe.s',

        # Board support packages.
        '<(stm32_cube_f4_bsp_nucleo)/stm32f4xx_nucleo.c',

        # Drivers.
        '<(stm32_cube_f4)/Drivers/BSP/Components/st7735/st7735.c',
        '<(stm32_cube_f4)/Drivers/BSP/Adafruit_Shield/stm32_adafruit_lcd.c',
        '<(stm32_cube_f4)/Drivers/BSP/Adafruit_Shield/stm32_adafruit_sd.c',
        '<(stm32_cube_f4)/Middlewares/Third_Party/FatFs/src/ff.c',
        '<(stm32_cube_f4)/Middlewares/Third_Party/FatFs/src/ff_gen_drv.c',
        '<(stm32_cube_f4)/Middlewares/Third_Party/FatFs/src/diskio.c',
        '<(stm32_cube_f4)/Middlewares/Third_Party/FatFs/src/drivers/'
            'sd_diskio.c',
      ],
      'conditions': [
        ['OS=="linux"', {
          'cflags' : [
            '<@(additional_gcc_warning_flags)',
          ],
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_CFLAGS' : [
              '<@(additional_gcc_warning_flags)',
            ],
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
      ],
    },
    {
      'variables': {
        'project_name': 'stm32f411re_nucleo_demonstrations',
      },
      'type': 'none',
      'target_name': 'stm32f411re_nucleo_demonstrations',
      'dependencies' : [
        'stm32f411re_nucleo_demonstrations.elf'
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
  ],
}
