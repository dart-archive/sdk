# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

{
  'targets': [
     {
       'target_name': 'demos',
       'type': 'none',
       'dependencies': [
         'stm32_cube_f4_demos.gyp:stm32f4_discovery_demonstrations',
         'stm32_cube_f4_demos.gyp:stm32f411re_nucleo_demonstrations',
      ],
    },
    {
      'target_name': 'nucleo_dartino',
      'type': 'none',
      'dependencies': [
        'disco_dartino/nucleo_dartino.gyp:nucleo_dartino',
      ],
    },
  ],
}
