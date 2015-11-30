# Copyright (c) 2012 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This is an gyp include to use YASM for compiling assembly files.
#
# Files to be compiled with YASM should have an extension of .asm.
#
# There are three variables for this include:
# yasm_flags : Pass additional flags into YASM.
# yasm_output_path : Output directory for the compiled object files.
# yasm_includes : Includes used by .asm code.  Changes to which should force
#                 recompilation.
#
# Sample usage:
# 'sources': [
#   'ultra_optimized_awesome.asm',
# ],
# 'variables': {
#   'yasm_flags': [
#     '-I', 'assembly_include',
#   ],
#   'yasm_output_path': '<(SHARED_INTERMEDIATE_DIR)/project',
#   'yasm_includes': ['ultra_optimized_awesome.inc']
# },
# 'includes': [
#   'third_party/yasm/yasm_compile.gypi'
# ],

{
  'variables': {
    'yasm_flags': [],
    'yasm_includes': [],
    'yasm_path': '<(PRODUCT_DIR)/yasm<(EXECUTABLE_SUFFIX)',
  },  # variables

  'conditions': [
    # Only depend on YASM on windows.
    ['OS=="win"', {
      'dependencies': [
        '<(DEPTH)/third_party/yasm/yasm.gyp:yasm#host',
      ],
    }],
  ],  # conditions

  'rules': [
    {
      'rule_name': 'assemble',
      'extension': 'asm',
      'inputs': [ '<(yasm_path)', '<@(yasm_includes)'],
      'outputs': [
        '<(yasm_output_path)/<(RULE_INPUT_ROOT).obj',
      ],
      'action': [
        '<(yasm_path)',
        '<@(yasm_flags)',
        '-o', '<(yasm_output_path)/<(RULE_INPUT_ROOT).obj',
        '<(RULE_INPUT_PATH)',
      ],
      'process_outputs_as_sources': 1,
      'message': 'Compile assembly (YASM) <(RULE_INPUT_PATH)',
    },
  ],  # rules
}
