# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.
{
  'targets': [
    {
      'target_name': 'generate_version_cc',
      'type': 'none',
      'toolsets': ['host'],
      'actions': [
        {
          'action_name': 'generate_version_cc_action',
          'inputs': [
            'tools/generate_version_cc.py',
            '.git/info/refs',
            '.git/HEAD',
          ],
          'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/version.cc',
          ],
          'action': [
            'python', '<@(_inputs)', '<@(_outputs)',
          ],
        },
      ],
    },
  ],
}
