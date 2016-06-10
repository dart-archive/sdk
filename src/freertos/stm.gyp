# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
     {
      'target_name': 'demos',
      'type': 'none',
      'dependencies': [
        'stm32_cube_f7_demos.gyp:STemWin_HelloWorld',
        'stm32_cube_f7_demos.gyp:Audio_playback_and_record',
        'stm32_cube_f7_demos.gyp:LwIP_HTTP_Server_Netconn_RTOS',
        'stm32_cube_f7_demos.gyp:Demonstration',
      ],
    },
    {
      'target_name': 'disco_dartino',
      'type': 'none',
      'dependencies': [
        'disco_dartino.gyp:disco_746_dartino',
      ],
    },
  ],
}
