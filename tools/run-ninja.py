#!/usr/bin/env python
# Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import platform
import subprocess
import sys

def Main():
  if platform.system() == "Windows":
    ninjafile = "build-windows.ninja"
  else:
    ninjafile = "build.ninja"

  ninja_command = ["ninja", "-f", ninjafile] + sys.argv[1:]
  print "Running: %s" % " ".join(ninja_command)
  subprocess.check_call(ninja_command)

if __name__ == '__main__':
  sys.exit(Main())
