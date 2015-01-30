#!/usr/bin/env python
#
# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import shutil
import sys

def Main():
  # Clean ninja output.
  shutil.rmtree("out", ignore_errors=True)
  # Clean scons output.
  shutil.rmtree("build", ignore_errors=True)
  return 0

if __name__ == '__main__':
  sys.exit(Main())
