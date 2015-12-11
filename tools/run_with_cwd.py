#!/usr/bin/python

# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import sys
import utils
import subprocess

def Main():
  with utils.ChangedWorkingDirectory(sys.argv[1]):
    subprocess.check_call(sys.argv[2:])

if __name__ == '__main__':
  Main()
