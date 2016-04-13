# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
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
            '../../../third_party/gcc-arm-embedded/<(OS)/'
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
      'target_name': 'libfreertos_dartino',
      'variables': {
        'source_path': 'src',
        'generated_path': 'generated',
        'template_path': 'template',
        'common_cflags': [
          # Our target will link in the CMSIS-RTOS files which do have a
          # few warnings.
          '-Wno-write-strings',
          '-Wno-sign-compare',
          '-Wno-missing-field-initializers',
        ],
      },
      'type': 'static_library',
      'standalone_static_library': 1,
      'includes': [
        '../free_rtos_sources.gypi',
      ],
      'include_dirs': [
        '<(generated_path)/Inc',
        '<(source_path)',
      ],
      'sources': [
        # Application.
        '<(source_path)/cmpctmalloc.c',
        '<(source_path)/cmpctmalloc.h',
        '<(source_path)/device_manager.h',
        '<(source_path)/device_manager.cc',
        '<(source_path)/device_manager_api.h',
        '<(source_path)/device_manager_api_impl.cc',
        '<(source_path)/freertos.cc',
        '<(source_path)/FreeRTOSConfig.h',
        '<(source_path)/dartino_entry.cc',
        '<(source_path)/main.cc',
        '<(source_path)/page_allocator.cc',
        '<(source_path)/page_allocator.h',

        '<(source_path)/syscalls.c',

        '<(source_path)/exceptions.c',

        # Buffer allocation scheme.
        '<(freertos_plus_tcp)/portable/BufferManagement/BufferAllocation_2.c',
      ],
      'conditions': [
        ['OS=="linux"', {
          'cflags': [
            '<@(common_cflags)',
          ],
        }],
        ['OS=="mac"', {
          'xcode_settings': {
            'OTHER_CFLAGS': [
              '<@(common_cflags)',
            ],
            'OTHER_CPLUSPLUSFLAGS' : [
              '<@(common_cflags)',
            ],
          },
        }],
      ],
    },
    {
      'type': 'static_library',
      'target_name': 'embedder_options.o',
      'actions': [
        {
          'action_name': 'build_embedder_options',
          'inputs': [
            'src/embedder_options.c',
          ],
          'outputs': [
            '<(PRODUCT_DIR)/embedder_options.o',
          ],
          'action': [
            '../../../third_party/gcc-arm-embedded/<(OS)/'
                'gcc-arm-embedded/bin/arm-none-eabi-gcc',
            '-mcpu=cortex-m7',
            '-mthumb',
            '-mfloat-abi=hard',
            '-mfpu=fpv5-sp-d16',
            '-o',
            '<(PRODUCT_DIR)/embedder_options.o',
            '-c',
            'src/embedder_options.c',
          ]
        },
      ],
    },
  ],
}
