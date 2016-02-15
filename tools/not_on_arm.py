#!/usr/bin/python
# Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import platform
import subprocess
import sys

def Main():
  # platform.machine() looks like 'armv7l' or 'i386'
  if not platform.machine().startswith('arm'):
    print 'Runing %s' % ' '.join(sys.argv[1:])
    subprocess.check_call(sys.argv[1:])
  else:
    print 'Skipping "%s" on arm' % ' '.join(sys.argv[1:])

if __name__ == '__main__':
  Main()

