#!/usr/bin/env python
#
# Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import sys

import utils

def Main():
  print utils.GetVersion()

if __name__ == '__main__':
  sys.exit(Main())
