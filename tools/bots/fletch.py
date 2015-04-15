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

    with bot.BuildStep('warnings'):
      # TODO(ahe): Make this check part of the build.
      output = subprocess.check_output([
        "./out/ReleaseIA32Clang/dart",
        "-ppackage/",
        "package/compiler/src/dart2js.dart",
        "-ppackage/", # For dart2js.
        "--library-root=../dart/sdk/",
        "--analyze-only",
        "--categories=Server",
        "package:fletchc/src/driver.dart"])
      if output: # output from dart2js should be empty.
        print output
        print '@@@STEP_FAILURE@@@'
        sys.stdout.flush()

    for configuration in configurations:
      if mac and configuration['arch'] == 'x64' and configuration['asan']:
        # Asan/x64 takes a long time on mac.
        pass
      else:
        RunTests(
          configuration['build_conf'],
          configuration['mode'],
          configuration['arch'],
          mac=mac,
          clang=configuration['clang'],
          asan=configuration['asan'])
        if configuration['arch'] == 'x64' and configuration['mode'] == 'debug':
          KillFletch(config)
          RunTests(
            'driver_%s' % configuration['build_conf'],
            configuration['mode'],
            configuration['arch'],
            mac=mac,
            clang=configuration['clang'],
            asan=configuration['asan'],
            fletch_driver=True)
          KillFletch(config)


def RunTests(name, mode, arch,
             mac=False, clang=True, asan=False, fletch_driver=False):
  with bot.BuildStep('Test %s' % name, swallow_error=True):
    args = ['python', 'tools/test.py', '-m%s' % mode, '-a%s' % arch,
            '--time', '--report', '-pbuildbot', '--step_name=test_%s' % name]
    if asan:
      args.append('--asan')

    if clang:
      args.append('--clang')

    if fletch_driver:
      args.extend(['-rfletchc', '-cnone', '--host-checked'])
      # TODO(ahe): Run all test suites.
      args.append('language')
      # TODO(ahe): Remove shard arguments.
      args.extend(['--shards=20', '--shard=1'])
      # TODO(ahe): Remove -j option. It's needed temporarily, as driver.dart
      # doesn't spawn new isolates. So if one tests times out, tasks-1 other
      # tests might also be seen as timing out.
      args.append('-j1')

    Run(args)


if __name__ == '__main__':
  bot.RunBot(Config, Steps, build_step=None)
