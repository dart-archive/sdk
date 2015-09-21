#!/usr/bin/env python
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

import os
import subprocess
import sys

version_gyp_template = """\
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
            '%(ref)s',
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
""";


def Main():
  args = sys.argv[1:]
  version_gyp = args[0]
  current_content = None
  if os.path.isfile(version_gyp):
    with open(version_gyp, "r") as f:
      current_content = f.read()
  ref = subprocess.check_output(
    ["git", "rev-parse", "--symbolic-full-name", "HEAD"]).strip()
  if (ref == "HEAD"):
    ref = ".git/HEAD"
  else:
    ref = ".git/%s" % ref
  updated_content = version_gyp_template % {"ref": ref}
  if updated_content != current_content:
    with open(version_gyp, 'w') as f:
      f.write(updated_content)
  return 0


if __name__ == '__main__':
  sys.exit(Main())
