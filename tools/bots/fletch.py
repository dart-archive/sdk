#!/usr/bin/python

# Copyright (c) 2014, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

"""
Buildbot steps for fletch testing
"""

import os
import re
import subprocess
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


def KillFletch(config):
  if config.system != 'windows':
    # Kill any lingering dart processes (from fletch_driver).
    subprocess.call("killall dart", shell=True)
    subprocess.call("killall fletch_driver", shell=True)
    subprocess.call("killall fletch", shell=True)


def Steps(config):
  SetupEnvironment(config)
  if config.system == 'mac':
    # gcc on mac is just an alias for clang.
    compiler_variants = ['Clang']
  else:
    compiler_variants = ['', 'Clang']

  mac = config.system == 'mac'

  # This makes us work from whereever we are called, and restores CWD in exit.
  with utils.ChangedWorkingDirectory(FLETCH_PATH):

    with bot.BuildStep('GYP'):
      Run(['ninja', '-v'])

    configurations = []

    for asan_variant in ['', 'Asan']:
      for compiler_variant in compiler_variants:
        for mode in ['Debug', 'Release']:
          for arch in ['IA32', 'X64']:
            build_conf = '%(mode)s%(arch)s%(clang)s%(asan)s' % {
              'mode': mode,
              'arch': arch,
              'clang': compiler_variant,
              'asan': asan_variant,
            }
            configurations.append({
              'build_conf': build_conf,
              'build_dir': 'out/%s' % build_conf,
              'clang': bool(compiler_variant),
              'asan': bool(asan_variant),
              'mode': mode.lower(),
              'arch': arch.lower(),
            })

    for configuration in configurations:
      with bot.BuildStep('Build %s' % configuration['build_conf']):
        Run(['ninja', '-v', '-C', configuration['build_dir']])

    with bot.BuildStep('incremental', swallow_error=True):
      dart_vm = './third_party/bin/linux/dart'
      if mac:
        dart_vm = './third_party/bin/mac/dart'
      output = None
      try:
        output = subprocess.check_output([
          dart_vm, '-Dfletch-vm=out/DebugX64Clang/fletch',
          '-Ddart-sdk=../dart/sdk/', '-c', '-ppackage/',
          'tests/fletchc/incremental/feature_test.dart'])
      except subprocess.CalledProcessError as error:
        print error
        raise OSError()
      last_line = output.split('\n')[-2]
      if last_line != 'unittest-suite-success':
        print output
        print 'Last line of output not: "unittest-suite-success".'
        raise OSError()

    for full_run in [True, False]:
      for configuration in configurations:
        if mac and configuration['arch'] == 'x64' and configuration['asan']:
          # Asan/x64 takes a long time on mac.
          continue

        if full_run and configuration['build_conf'] != 'DebugIA32':
          # We only do full runs on DebugIA32 for now.
          # full_run = compile to snapshot &
          #            run shapshot &
          #            run shapshot with `-Xunfold-program`
          continue

        RunTests(
          configuration['build_conf'],
          configuration['mode'],
          configuration['arch'],
          config,
          mac=mac,
          clang=configuration['clang'],
          asan=configuration['asan'],
          full_run=full_run)


def RunTests(name, mode, arch, config, mac=False, clang=True, asan=False,
             full_run=False):
  step_name = '%s%s' % (name, '-full' if full_run else '')
  with bot.BuildStep('Test %s' % step_name, swallow_error=True):
    args = ['python', 'tools/test.py', '-m%s' % mode, '-a%s' % arch,
            '--time', '--report', '-pbuildbot',
            '--step_name=test_%s' % step_name,
            '--host-checked']
    if full_run:
      # We let package:fletchc/fletchc.dart compile tests to snapshots.
      # Afterwards we run the snapshot with
      #  - normal fletch VM
      #  - fletch VM with -Xunfold-program enabled
      args.extend(['-cfletchc', '-rfletchvm'])
    else:
      # We just let package:fletchc/fletchc.dart compile & run tests.
      args.extend(['-cnone', '-rfletchc,fletchd'])

    if asan:
      args.append('--asan')

    if clang:
      args.append('--clang')

    KillFletch(config)

    Run(args)

    KillFletch(config)


if __name__ == '__main__':
  bot.RunBot(Config, Steps, build_step=None)
