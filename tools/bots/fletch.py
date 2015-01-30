#!/usr/bin/python

# Copyright (c) 2014, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

"""
Buildbot steps for fletch testing
"""

import re
import os
import sys

import bot
import bot_utils

utils = bot_utils.GetUtils()

FLETCH_REGEXP = r'fletch-(linux|mac|windows)'
dirname = os.path.dirname
FLETCH_PATH = dirname(dirname(dirname(os.path.abspath(__file__))))

def Config(name, is_buildbot):
  match = re.match(FLETCH_REGEXP, name)
  if not match:
    print('Builder regexp did not match')
    exit(1)
  # We don't really need this, but it is just much easier than doing all the
  # boilerplate outselves
  return bot.BuildInfo('none', 'none', 'release', match.group(1))

def Run(args):
  print "Running: %s" % ' '.join(args)
  sys.stdout.flush()
  bot.RunProcess(args)

def SetupEnvironment(config):
  if config.system != 'windows':
    os.environ['PATH'] = '%s/third_party/clang/%s/bin:%s' % (
        FLETCH_PATH, config.system, os.environ['PATH'])
  if config.system == 'mac':
    mac_library_path = "third_party/clang/mac/lib/clang/3.6.0/lib/darwin"
    os.environ['DYLD_LIBRARY_PATH'] = '%s/%s' % (FLETCH_PATH, mac_library_path)


def Steps(config):
  SetupEnvironment(config)
  # gcc on mac is just an alias for clang.
  run_gcc = config.system == 'linux'
  gyp_build = True
  # This makes us work from whereever we are called, and restores CWD in exit.
  with utils.ChangedWorkingDirectory(FLETCH_PATH):

    if gyp_build:
      with bot.BuildStep('ninja DebugIA32'):
        Run(['ninja', '-v', '-C', 'out/DebugIA32'])
      with bot.BuildStep('ninja ReleaseIA32'):
        Run(['ninja', '-v', '-C', 'out/ReleaseIA32'])
      with bot.BuildStep('ninja DebugX64'):
        Run(['ninja', '-v', '-C', 'out/DebugX64'])
      with bot.BuildStep('ninja ReleaseX64'):
        Run(['ninja', '-v', '-C', 'out/ReleaseX64'])

    if run_gcc:
      with bot.BuildStep('Build (gcc)'):
        Run(['python', 'third_party/scons/scons.py',
             '-j%s' % utils.GuessCpus()])
      RunTests('gcc')
      with bot.BuildStep('Build (gcc+asan)'):
        Run(['python', 'third_party/scons/scons.py', '-j%s' % utils.GuessCpus(),
            'asan=true'])
      RunTests('gcc', asan=True)

    with bot.BuildStep('Build (clang)'):
      Run(['python', 'third_party/scons/scons.py', '-j%s' % utils.GuessCpus(),
           'clang=true'])
    RunTests('clang')
    RunTests('clang', scons=False)
    with bot.BuildStep('Build (clang+asan)'):
      Run(['python', 'third_party/scons/scons.py', '-j%s' % utils.GuessCpus(),
           'clang=true', 'asan=true'])
    # Asan debug mode takes a long time on mac.
    modes = ['release'] if config.system == 'mac' else ['release', 'debug']
    RunTests('clang', asan=True, modes=modes)
    RunTests('clang', asan=True, modes=modes, scons=False)


def RunTests(name, asan=False, modes=None, scons=True):
  asan_str = '-asan' if asan else ''
  scons_str = '-scons' if scons else '-GYP'
  modes = modes or ['release', 'debug']
  for mode in modes:
    with bot.BuildStep('Test (%s%s%s-%s)' % (name, scons_str, asan_str, mode),
                       swallow_error=True):
      args = ['python', 'tools/test.py', '-m%s' % mode, '-aia32,x64',
              '--time', '--report', '--progress=buildbot']
      if asan:
        args.extend(['--asan', '--builder-tag=asan'])
      if not scons:
        args.extend(['--no-scons', '--builder-tag=ninja'])
      Run(args)

if __name__ == '__main__':
  bot.RunBot(Config, Steps, build_step=None)
