#!/usr/bin/env python
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

import os
import sys
import utils

version_cc_template = """\
// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/version.h"

namespace fletch {

extern "C"
const char* GetVersion() {
  return "%(version)s";
}

}  // namespace fletch
""";


def Main():
  args = sys.argv[1:]
  version_cc = args[2]
  version = utils.GetSemanticSDKVersion()
  updated_content = version_cc_template % {"version": version}
  with open(version_cc, 'w') as f:
    f.write(updated_content)
  return 0


if __name__ == '__main__':
  sys.exit(Main())
