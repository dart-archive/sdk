#!/usr/bin/env python
# Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import os
import string
import subprocess
import sys

import utils

def MaybeRunGclientHooks(arguments):
  def ToInt(string):
    try:
      return int(string)
    except ValueError:
      return None

  for argument in arguments:
    if argument.startswith('--run-gclient-hooks'):
      if ToInt(argument.split("=")[1]) == 0:
        return

  # This needs to happen here, before launching the Dart VM, as the hooks
  # may update the Dart binary returned by utils.DartBinary().
  gclient_command = ["gclient", "runhooks"];
  print "Running: %s" % " ".join(gclient_command)
  print "Use --run-gclient-hooks=0 to skip this step."
  subprocess.check_call(gclient_command)

def UpdateAsanOptions():
  options = []
  if 'ASAN_OPTIONS' in os.environ:
    options.append(os.environ['ASAN_OPTIONS'])
  options.append('abort_on_error=1')
  os.environ['ASAN_OPTIONS'] = ','.join(options)

def Main():
  args = sys.argv[1:]
  MaybeRunGclientHooks(args)
  UpdateAsanOptions();
  tools_dir = os.path.dirname(os.path.realpath(__file__))
  dart_script_name = 'test.dart'
  dart_test_script = string.join([tools_dir, dart_script_name], os.sep)
  command = [utils.DartBinary(), '--checked', dart_test_script] + args
  exit_code = subprocess.call(command)
  utils.DiagnoseExitCode(exit_code, command)
  return exit_code


if __name__ == '__main__':
  sys.exit(Main())
