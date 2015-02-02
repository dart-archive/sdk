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

  mac = config.system == 'mac'

  # This makes us work from whereever we are called, and restores CWD in exit.
  with utils.ChangedWorkingDirectory(FLETCH_PATH):

    for build_conf in ['DebugIA32', 'ReleaseIA32', 'DebugX64', 'ReleaseX64']:
      with bot.BuildStep('ninja %s' % build_conf):
        Run(['ninja', '-v', '-C', 'out/%s' % build_conf])
      with bot.BuildStep('ninja %sAsan' % build_conf):
        Run(['ninja', '-v', '-C', 'out/%sAsan' % build_conf])
      if run_gcc:
        # TODO(ahe): Rename something. It is confusing that the extra step is
        # running clang when the variable is called "run_gcc". The default
        # build is gcc on Linux, and clang on Mac, and there's no gcc on Mac.
        with bot.BuildStep('ninja clang %s' % build_conf):
          Run(['ninja', '-v', '-C', 'clang_out/%s' % build_conf])
        with bot.BuildStep('ninja clang %sAsan' % build_conf):
          Run(['ninja', '-v', '-C', 'clang_out/%sAsan' % build_conf])

    if run_gcc:
      with bot.BuildStep('Build (gcc)'):
        Run(['python', 'third_party/scons/scons.py',
             '-j%s' % utils.GuessCpus()])
      RunTests('gcc', mac=mac)
      with bot.BuildStep('Build (gcc+asan)'):
        Run(['python', 'third_party/scons/scons.py', '-j%s' % utils.GuessCpus(),
            'asan=true'])
      RunTests('gcc', asan=True, mac=mac)

    with bot.BuildStep('Build (clang)'):
      Run(['python', 'third_party/scons/scons.py', '-j%s' % utils.GuessCpus(),
           'clang=true'])
    RunTests('clang', mac=mac)
    RunTests('clang', scons=False, mac=mac)
    with bot.BuildStep('Build (clang+asan)'):
      Run(['python', 'third_party/scons/scons.py', '-j%s' % utils.GuessCpus(),
           'clang=true', 'asan=true'])
    # Asan debug mode takes a long time on mac.
    modes = ['release'] if config.system == 'mac' else ['release', 'debug']
    RunTests('clang', asan=True, modes=modes, mac=mac)
    RunTests('clang', asan=True, modes=modes, scons=False, mac=mac)


def RunTests(name, asan=False, modes=None, scons=True, mac=False):
  asan_str = '-asan' if asan else ''
  scons_str = '-scons' if scons else '-ninja'
  modes = modes or ['release', 'debug']
  for mode in modes:
    for arch in ['ia32' , 'x64']:
      with bot.BuildStep(
          'Test (%s%s%s-%s-%s)' % (name, scons_str, asan_str, mode, arch),
          swallow_error=True):
        args = ['python', 'tools/test.py', '-m%s' % mode, '-a%s' % arch,
                '--time', '--report', '--progress=buildbot']
        if asan:
          args.append('--asan')
          if arch == 'x64' and mac:
            # On Mac x64, asan seems to be bound by a syscall that doesn't
            # parallelize.
            args.append('-j1')
        if not scons:
          args.append('--no-scons')

        Run(args)

if __name__ == '__main__':
  bot.RunBot(Config, Steps, build_step=None)
