#!/usr/bin/python

# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import os
import sys
import utils

def invoke_ar(args):
  library_name = args[len(args) - 1]
  libraries = args[:-1]
  script = 'create %s\\n' % library_name
  for lib in libraries:
    script += 'addlib %s\\n' % lib
  script += 'save\\n'
  script += 'end\\n'
  os.system('env echo -e "%s" | ar -M' % script)

def invoke_libtool(args):
  library_name = args[len(args) - 1]
  libraries = args[:-1]
  command = 'libtool -static -o %s' % library_name
  for lib in libraries:
    command += ' %s' % lib
  os.system(command)

def main():
  args = sys.argv[1:]
  os_name = utils.GuessOS()
  if os_name == 'linux':
    invoke_ar(args)
  elif os_name == 'macos':
    invoke_libtool(args)

if __name__ == '__main__':
  main()
