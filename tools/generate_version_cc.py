#!/usr/bin/env python
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

import os
import sys
import utils

version_cc_template = """\
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/version.h"

namespace fletch {

const char* GetVersion() {
  return "%(version)s";
}

}  // namespace fletch
""";


def Main():
  args = sys.argv[1:]
  version_cc = args[1]
  current_content = None
  if os.path.isfile(version_cc):
    with open(version_cc, "r") as f:
      current_content = f.read()
  version = utils.GetGitRevision()
  updated_content = version_cc_template % {"version": version}
  if (updated_content != current_content):
    with open(version_cc, 'w') as f:
      f.write(updated_content)
  return 0


if __name__ == '__main__':
  sys.exit(Main())
