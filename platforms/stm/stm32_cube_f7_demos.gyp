# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'variables': {
    'discovery_projects': '<(stm32_cube_f7)/Projects/STM32746G-Discovery',
  },
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
    'cflags' : [
      '-Wno-empty-body',
      '-Wno-missing-field-initializers',
      '-Wno-sign-compare',
    ],
  },
  'targets': [
    {
      'target_name': 'FMC_SDRAM.elf',
      'variables': {
        'project_name': 'FMC_SDRAM',
        'project_path':
          '<(discovery_projects)/Examples/FMC/<(project_name)',
        'project_include_path': '<(project_path)/Inc/',
        'project_source_path': '<(project_path)/Src/',
        'ldflags': [
          '-specs=nosys.specs',
          '-specs=nano.specs',
          '-L<(stm32_cube_f7)/Middlewares/ST/STemWin/Lib/',
          '-T<(project_path)/SW4STM32/STM32746G_DISCOVERY/'
              'STM32F746NGHx_FLASH.ld',
        ],
      },
      'type': 'executable',
      'includes': [
        'hal_sources.gypi',
      ],
      'include_dirs': [
        '<(project_include_path)',
      ],
      'sources': [
        # Application.
        '<(project_source_path)/main.c',
        '<(project_source_path)/stm32f7xx_hal_msp.c',

        # Board initialization and interrupt service routines.
        '<(project_source_path)/stm32f7xx_it.c',
        '<(project_source_path)/system_stm32f7xx.c',
        '<(project_path)/SW4STM32/startup_stm32f746xx.s',

        # Board support packages.
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
        ['OS=="linux"', {
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
      ],
    },
    {
      'variables': {
        'project_name': 'FMC_SDRAM',
      },
      'type': 'none',
      'target_name': 'FMC_SDRAM',
      'dependencies' : [
        'FMC_SDRAM.elf'
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
      'target_name': 'FMC_SDRAM_DataMemory.elf',
      'variables': {
        'project_name': 'FMC_SDRAM_DataMemory',
        'project_path':
          '<(discovery_projects)/Examples/FMC/<(project_name)',
        'project_include_path': '<(project_path)/Inc/',
        'project_source_path': '<(project_path)/Src/',
        'ldflags': [
          '-specs=nosys.specs',
          '-specs=nano.specs',
          '-L<(stm32_cube_f7)/Middlewares/ST/STemWin/Lib/',
          '-T<(project_path)/SW4STM32/STM32746G_DISCOVERY/'
              'STM32F746NGHx_FLASH.ld',
        ],
      },
      'type': 'executable',
      'includes': [
        'hal_sources.gypi',
      ],
      'include_dirs': [
        '<(project_include_path)',
      ],
      'sources': [
        # Application.
        '<(project_source_path)/main.c',
        #'<(project_source_path)/stm32f7xx_hal_msp.c',

        # Board initialization and interrupt service routines.
        '<(project_source_path)/stm32f7xx_it.c',
        '<(project_source_path)/system_stm32f7xx.c',
        '<(project_path)/SW4STM32/startup_stm32f746xx.s',

        # Board support packages.
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
        ['OS=="linux"', {
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
      ],
    },
    {
      'variables': {
        'project_name': 'FMC_SDRAM_DataMemory',
      },
      'type': 'none',
      'target_name': 'FMC_SDRAM_DataMemory',
      'dependencies' : [
        'FMC_SDRAM_DataMemory.elf'
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
      'target_name': 'STemWin_HelloWorld.elf',
      'variables': {
        'project_name': 'STemWin_HelloWorld',
        'project_path':
          '<(discovery_projects)/Applications/STemWin/<(project_name)',
        'project_include_path': '<(project_path)/Inc/',
        'project_source_path': '<(project_path)/Src/',
        'ldflags': [
          '-specs=nosys.specs',
          '-specs=nano.specs',
          '-L<(stm32_cube_f7)/Middlewares/ST/STemWin/Lib/',
          '-T<(project_path)/SW4STM32/STM32746G_DISCOVERY/'
              'STM32F746NGHx_FLASH.ld',
        ],
      },
      'type': 'executable',
      'includes': [
        'hal_sources.gypi',
      ],
      'include_dirs': [
        '<(project_include_path)',
      ],
      'sources': [
        # Application.
        '<(project_source_path)/GUIConf.c',
        '<(stm32_cube_f7)/Middlewares/ST/STemWin/OS/GUI_X.c',
        '<(project_source_path)/LCDConf.c',
        '<(project_source_path)/BASIC_HelloWorld.c',
        '<(project_source_path)/main.c',

        # Board initialization and interrupt service routines.
        '<(project_source_path)/stm32f7xx_it.c',
        '<(project_source_path)/system_stm32f7xx.c',
        '<(project_path)/SW4STM32/startup_stm32f746xx.s',

        # Board support packages.
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_sdram.c',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
        ['OS=="linux"', {
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
      ],
      'libraries': [
        '-l:STemWin528_CM7_GCC.a',
        '-lm',
      ],
    },
    {
      'variables': {
        'project_name': 'STemWin_HelloWorld',
      },
      'type': 'none',
      'target_name': 'STemWin_HelloWorld',
      'dependencies' : [
        'STemWin_HelloWorld.elf'
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
      'target_name': 'Audio_playback_and_record.elf',
      'variables': {
        'project_name': 'Audio_playback_and_record',
        'project_path':
          '<(discovery_projects)/Applications/Audio/<(project_name)',
        'project_include_path': '<(project_path)/Inc/',
        'project_source_path': '<(project_path)/Src/',
        'usb_host_library':
          '<(stm32_cube_f7)/Middlewares/ST/STM32_USB_Host_Library/',
        'ldflags': [
          '-specs=nosys.specs',
          '-specs=nano.specs',
          '-T<(project_path)/SW4STM32/STM32F7-DISCO/STM32F746NGHx_FLASH.ld',
        ],
      },
      'type': 'executable',
      'includes': [
        'hal_sources.gypi',
      ],
      'defines': [
        'USE_IOEXPANDER',
        'USE_USB_FS',
      ],
      'include_dirs': [
        '<(project_include_path)',
      ],
      'includes': [
        'hal_sources.gypi',
      ],
      'sources': [
        # Application.
        '<(project_source_path)/explorer.c',
        '<(project_source_path)/main.c',
        '<(project_source_path)/menu.c',
        '<(project_source_path)/usbh_conf.c',
        '<(project_source_path)/usbh_diskio.c',
        '<(project_source_path)/waveplayer.c',
        '<(project_source_path)/waverecorder.c',

        '<(stm32_cube_f7)/Utilities/Log/lcd_log.c',
        '<(stm32_cube_f7)/Middlewares/Third_Party/FatFs/src/ff.c',
        '<(usb_host_library)/Core/Src/usbh_core.c',
        '<(usb_host_library)/Core/Src/usbh_ctlreq.c',
        '<(usb_host_library)/Core/Src/usbh_ioreq.c',
        '<(usb_host_library)/Core/Src/usbh_pipes.c',
        '<(usb_host_library)/Class/MSC/Src/usbh_msc.c',
        '<(usb_host_library)/Class/MSC/Src/usbh_msc_bot.c',
        '<(usb_host_library)/Class/MSC/Src/usbh_msc_scsi.c',

        # Board initialization and interrupt service routines.
        '<(project_source_path)/stm32f7xx_it.c',
        '<(project_source_path)/system_stm32f7xx.c',
        '<(project_path)/SW4STM32/startup_stm32f746xx.s',

        # Board support packages.
        '<(stm32_cube_f7)/Drivers/BSP/Components/ft5336/ft5336.c',
        '<(stm32_cube_f7)/Drivers/BSP/Components/wm8994/wm8994.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_sdram.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_lcd.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_audio.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_ts.c',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
        ['OS=="linux"', {
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
      ],
    },
    {
      'variables': {
        'project_name': 'Audio_playback_and_record',
      },
      'type': 'none',
      'target_name': 'Audio_playback_and_record',
      'dependencies' : [
        'Audio_playback_and_record.elf'
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
      'target_name': 'LwIP_HTTP_Server_Netconn_RTOS.elf',
      'variables': {
        'project_name': 'LwIP_HTTP_Server_Netconn_RTOS',
        'project_path':
          '<(discovery_projects)/Applications/LwIP/<(project_name)',
        'project_include_path': '<(project_path)/Inc/',
        'project_source_path': '<(project_path)/Src/',
        'ldflags': [
          '-T<(project_path)/SW4STM32/STM32746G_DISCOVERY/'
              'STM32F746NGHx_FLASH.ld',
        ],
      },
      'cflags' : [
        '-Wno-format',
        '-Wno-address',
        '-Wno-pointer-sign',
      ],
      'type': 'executable',
      'includes': [
        'hal_sources.gypi',
        'lwip_sources.gypi',
        'free_rtos_sources.gypi',
      ],
      'include_dirs': [
        '<(project_include_path)',
      ],
      'sources': [
        # Application.
        '<(project_source_path)/app_ethernet.c',
        '<(project_source_path)/ethernetif.c',
        '<(project_source_path)/fs.c',
        '<(project_source_path)/httpserver-netconn.c',
        '<(project_source_path)/main.c',

        '<(project_path)/SW4STM32/syscalls.c',
        '<(stm32_cube_f7)/Utilities/Log/lcd_log.c',

        # Board initialization and interrupt service routines.
        '<(project_source_path)/stm32f7xx_it.c',
        '<(project_source_path)/system_stm32f7xx.c',
        '<(project_path)/SW4STM32/startup_stm32f746xx.s',

        # Board support packages.
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_sdram.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_lcd.c',

        # FreeRTOS malloc. Used to be included via free_rtos_sources.gypi.
        '<(stm32_cube_f7_free_rtos_src)/portable/MemMang/heap_3.c',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
        ['OS=="linux"', {
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
      ],
    },
    {
      'variables': {
        'project_name': 'LwIP_HTTP_Server_Netconn_RTOS',
      },
      'type': 'none',
      'target_name': 'LwIP_HTTP_Server_Netconn_RTOS',
      'dependencies' : [
        'LwIP_HTTP_Server_Netconn_RTOS.elf'
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
      'target_name': 'Demonstration.elf',
      'variables': {
        'project_name': 'Demonstration',
        'project_path': '<(discovery_projects)/<(project_name)',
        'usb_host_library':
          '<(stm32_cube_f7)/Middlewares/ST/STM32_USB_Host_Library/',
        'fat_fs_library': '<(stm32_cube_f7)/Middlewares/Third_Party/FatFs/',
        'ldflags': [
          '-specs=nosys.specs',
          '-specs=nano.specs',
          '-L<(stm32_cube_f7)/Middlewares/ST/STemWin/Lib/',
          '-L<(project_path)/STemWin_Addons/',
          '-T<(project_path)/SW4STM32/STM32F7-DISCO/STM32F746NGHx_FLASH.ld',
        ],
      },
      'type': 'executable',
      'includes': [
        'hal_sources.gypi',
        'lwip_sources.gypi',
        'free_rtos_sources.gypi',
      ],
      'defines': [
        'LWIP_TIMEVAL_PRIVATE=0',
        'DEMO_VERSION="1.0.1"',
      ],
      'cflags' : [
        '-Wno-format',
        '-Wno-address',
        '-Wno-pointer-sign',
      ],
      'include_dirs': [
        '<(project_path)/Core/Inc',
        '<(project_path)/Config',
        '<(project_path)/STemWin_Addons',
        '<(project_path)/Modules/audio_player/Addons/SpiritDSP_Equalizer',
        '<(project_path)/Modules/audio_player/Addons/SpiritDSP_LoudnessControl',
      ],
      'sources': [
        # Application.
        '<(project_path)/Config/GUIConf.c',
        '<(project_path)/Config/LCDConf.c',
        '<(project_path)/Config/usbh_conf.c',
        '<(project_path)/Core/Src/k_bsp.c',
        '<(project_path)/Core/Src/k_menu.c',
        '<(project_path)/Core/Src/k_module.c',
        '<(project_path)/Core/Src/k_rtc.c',
        '<(project_path)/Core/Src/k_startup.c',
        '<(project_path)/Core/Src/k_storage.c',
        '<(project_path)/Core/Src/main.c',
        '<(project_path)/Modules/audio_player/audio_player_app.c',
        '<(project_path)/Modules/audio_player/audio_player_win.c',
        '<(project_path)/Modules/Common/audio_if.c',
        '<(project_path)/Modules/videoplayer/video_player_win.c',
        '<(project_path)/Modules/audio_recorder/audio_recorder_app.c',
        '<(project_path)/Modules/audio_recorder/audio_recorder_win.c',
        '<(project_path)/Modules/games/games_win.c',
        '<(project_path)/Modules/gardening_control/gardening_control_win.c',
        '<(project_path)/Modules/home_alarme/home_alarm_win.c',
        '<(project_path)/Modules/settings/settings_win.c',
        '<(project_path)/Modules/vnc_server/ethernetif.c',
        '<(project_path)/Modules/vnc_server/vnc_app.c',
        '<(project_path)/Modules/vnc_server/vnc_server_win.c',

        '<(stm32_cube_f7)/Utilities/CPU/cpu_utils.c',

        '<(fat_fs_library)/src/diskio.c',
        '<(fat_fs_library)/src/ff.c',
        '<(fat_fs_library)/src/ff_gen_drv.c',
        '<(fat_fs_library)/src/drivers/usbh_diskio.c',
        '<(fat_fs_library)/src/option/syscall.c',
        '<(fat_fs_library)/src/option/unicode.c',

        '<(stm32_cube_f7)/Middlewares/ST/STemWin/OS/GUI_X_OS.c',

        '<(usb_host_library)/Core/Src/usbh_core.c',
        '<(usb_host_library)/Core/Src/usbh_ctlreq.c',
        '<(usb_host_library)/Core/Src/usbh_ioreq.c',
        '<(usb_host_library)/Core/Src/usbh_pipes.c',
        '<(usb_host_library)/Class/MSC/Src/usbh_msc.c',
        '<(usb_host_library)/Class/MSC/Src/usbh_msc_bot.c',
        '<(usb_host_library)/Class/MSC/Src/usbh_msc_scsi.c',

        # Board initialization and interrupt service routines.
        '<(project_path)/Core/Src/stm32f7xx_it.c',
        '<(project_path)/Core/Src/system_stm32f7xx.c',
        '<(project_path)/SW4STM32/startup_stm32f746xx.s',

        # Board support packages.
        '<(stm32_cube_f7)/Drivers/BSP/Components/ft5336/ft5336.c',
        '<(stm32_cube_f7)/Drivers/BSP/Components/wm8994/wm8994.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_audio.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_sdram.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_qspi.c',
        '<(stm32_cube_f7_bsp_discovery)/stm32746g_discovery_ts.c',

        # FreeRTOS malloc. Used to be included via free_rtos_sources.gypi.
        '<(stm32_cube_f7_free_rtos_src)/portable/MemMang/heap_3.c',
      ],
      'conditions': [
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_LDFLAGS': [
              '<@(ldflags)',
            ],
          },
        }],
        ['OS=="linux"', {
          'ldflags': [
            '<@(ldflags)',
          ],
        }],
      ],
      'libraries': [
        '-l:STM32746G_Discovery_STemWin_Addons_GCC.a',
        '-l:STemWin528_CM7_GCC.a',
        '-lm',
      ],
    },
    {
      'variables': {
        'project_name': 'Demonstration',
      },
      'type': 'none',
      'target_name': 'Demonstration',
      'dependencies' : [
        'Demonstration.elf'
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
