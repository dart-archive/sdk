#!/usr/bin/python

# Copyright (c) 2014, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

"""
Buildbot steps for fletch testing
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

import bot
import bot_utils

from os.path import dirname, join

utils = bot_utils.GetUtils()

DEBUG_LOG=".debug.log"

FLETCH_REGEXP = r'fletch-(linux|mac|windows)(-(debug|release|asan)-(x86))?'
CROSS_REGEXP = r'cross-fletch-(linux)-(arm)'
TARGET_REGEXP = r'target-fletch-(linux)-(debug|release)-(arm)'

FLETCH_PATH = dirname(dirname(dirname(os.path.abspath(__file__))))
GSUTIL = utils.GetBuildbotGSUtilPath()

GCS_BUCKET = 'gs://fletch-cross-compiled-binaries'

def Run(args):
  print "Running: %s" % ' '.join(args)
  sys.stdout.flush()
  bot.RunProcess(args)

def SetupClangEnvironment(system):
  if system != 'win32':
    os.environ['PATH'] = '%s/third_party/clang/%s/bin:%s' % (
        FLETCH_PATH, system, os.environ['PATH'])
  if system == 'macos':
    mac_library_path = "third_party/clang/mac/lib/clang/3.6.0/lib/darwin"
    os.environ['DYLD_LIBRARY_PATH'] = '%s/%s' % (FLETCH_PATH, mac_library_path)

def DisableMemoryLeakDetector():
  # See here for flags to asan:
  # https://code.google.com/p/address-sanitizer/wiki/Flags
  os.environ['ASAN_OPTIONS'] = 'detect_leaks=0'

def KillFletch(system):
  if system != 'windows':
    # Kill any lingering dart processes (from fletch_driver).
    subprocess.call("killall dart", shell=True)
    subprocess.call("killall fletch", shell=True)
    subprocess.call("killall fletch-vm", shell=True)

def Main():
  name, _ = bot.GetBotName()

  fletch_match = re.match(FLETCH_REGEXP, name)
  cross_match = re.match(CROSS_REGEXP, name)
  target_match = re.match(TARGET_REGEXP, name)

  if not fletch_match and not cross_match and not target_match:
    raise Exception('Invalid buildername')

  SetupClangEnvironment(utils.GuessOS())

  # TODO(ager/kustermann): We temporarily disable the leak detector due to
  # flakiness on our buildbot of the following form:
  #
  #   ASAN:SIGSEGV
  #   ==10777==LeakSanitizer has encountered a fatal error.
  #
  # See https://github.com/dart-lang/fletch/issues/56.
  DisableMemoryLeakDetector()

  # Clobber build directory if the checkbox was pressed on the BB.
  with utils.ChangedWorkingDirectory(FLETCH_PATH):
    bot.Clobber()

  # Accumulate daemon logs messages in '.debug.log' to be displayed on the
  # buildbot.Log
  with open(DEBUG_LOG, 'w') as debug_log:
    with utils.ChangedWorkingDirectory(FLETCH_PATH):

      if fletch_match:
        system = fletch_match.group(1)
        modes = ['debug', 'release']
        archs = ['ia32', 'x64']
        asans = [False, True]

        # Split configurations?
        partial_configuration = fletch_match.group(2)
        if partial_configuration:
          mode_or_asan = fletch_match.group(3)
          architecture_match = fletch_match.group(4)
          archs = {
              'x86' : ['ia32', 'x64'],
          }[architecture_match]

          # We split our builders into:
          #    fletch-linux-debug
          #    fletch-linux-release
          #    fletch-linux-asan (includes debug and release)
          if mode_or_asan == 'asan':
            modes = ['debug', 'release']
            asans = [True]
          else:
            modes = [mode_or_asan]
            asans = [False]

        StepsNormal(debug_log, system, modes, archs, asans)
      elif cross_match:
        system = cross_match.group(1)
        arch = cross_match.group(2)
        assert system == 'linux'
        assert arch == 'arm'

        modes = ['debug', 'release']
        arch = 'xarm'
        StepsCrossBuilder(debug_log, system, modes, arch)
      elif target_match:
        assert target_match.group(1) == 'linux'
        system = 'linux'
        mode = target_match.group(2)
        arch = 'xarm'
        StepsTargetRunner(debug_log, system, mode, arch)


#### Buildbot steps

def StepsNormal(debug_log, system, modes, archs, asans):
  configurations = GetBuildConfigurations(system, modes, archs, asans)

  # Generate ninja files.
  StepGyp()

  # Build all necessary configurations.
  for configuration in configurations:
    StepBuild(configuration['build_conf'], configuration['build_dir']);

  # Run tests on all necessary configurations.
  for snapshot_run in [True, False]:
    for configuration in configurations:
      if not ShouldSkipConfiguration(snapshot_run, configuration):
        StepTest(
          configuration['build_conf'],
          configuration['mode'],
          configuration['arch'],
          clang=configuration['clang'],
          asan=configuration['asan'],
          snapshot_run=snapshot_run,
          debug_log=debug_log,
          configuration=configuration)

def StepsCrossBuilder(debug_log, system, modes, arch):
  """This step builds XARM configurations and archives the results.

  The buildbot will trigger a build to run this cross builder. After it has
  built and archived build artifacts, the buildbot master will schedule a build
  for running the actual tests on a ARM device. The triggered build will
  eventually invoke the `StepsTargetRunner` function defined blow, which will
  take care of downloading/extracting the build artifacts and executing tests.
  """

  revision = os.environ['BUILDBOT_GOT_REVISION']
  assert revision

  for compiler_variant in GetCompilerVariants(system, arch):
    for mode in modes:
      build_conf = GetConfigurationName(mode, arch, compiler_variant, False)
      # TODO(kustermann): Once we have sorted out gyp/building issues with arm,
      # we should be able to build everything here.
      args = ['fletch-vm', 'fletch', 'natives.json', 'c_test_library']
      StepBuild(build_conf, os.path.join('out', build_conf), args=args)

  tarball = TarballName(arch, revision)
  try:
    with bot.BuildStep('Create build tarball'):
      Run(['tar',
           '-cjf', tarball,
           '--exclude=**/obj',
           '--exclude=**/obj.host',
           '--exclude=**/obj.target',
           'out'])

    with bot.BuildStep('Upload build tarball'):
      uri = "%s/%s" % (GCS_BUCKET, tarball)
      Run([GSUTIL, 'cp', tarball, uri])
      Run([GSUTIL, 'setacl', 'public-read', uri])
  finally:
    if os.path.exists(tarball):
      os.remove(tarball)

def StepsTargetRunner(debug_log, system, mode, arch):
  """This step downloads XARM build artifacts and runs tests.

  The buildbot master only triggers this step once the `StepCrossBuilder` step
  (defined above) has already been executed. This `StepsTargetRunner` can
  therefore download/extract the build artifacts which were archived by
  `StepCrossBuilder` and run the tests."""

  revision = os.environ['BUILDBOT_GOT_REVISION']

  tarball = TarballName(arch, revision)
  try:
    with bot.BuildStep('Fetch build tarball'):
      Run([GSUTIL, 'cp', "%s/%s" % (GCS_BUCKET, tarball), tarball])

    with bot.BuildStep('Unpack build tarball'):
      Run(['tar', '-xjf', tarball])

    # Run tests on all necessary configurations.
    configurations = GetBuildConfigurations(system, [mode], [arch], [False])
    for snapshot_run in [True, False]:
      for configuration in configurations:
        if not ShouldSkipConfiguration(snapshot_run, configuration):
          build_dir = configuration['build_dir']

          # Sanity check we got build artifacts which we expect.
          assert os.path.exists(os.path.join(build_dir, 'fletch-vm'))

          # TODO(kustermann): This is hackisch, but our current copying of the
          # dart binary makes this a requirement.
          dart_arm = 'third_party/bin/linux/dart-arm'
          destination = os.path.join(build_dir, 'dart')
          shutil.copyfile(dart_arm, destination)
          shutil.copymode(dart_arm, destination)

          StepTest(
            configuration['build_conf'],
            configuration['mode'],
            configuration['arch'],
            clang=configuration['clang'],
            asan=configuration['asan'],
            snapshot_run=snapshot_run,
            debug_log=debug_log,
            configuration=configuration)
  finally:
    if os.path.exists(tarball):
      os.remove(tarball)

    # We always clobber this to save disk on the arm board.
    bot.Clobber(force=True)


#### Buildbot steps helper

def StepGyp():
  with bot.BuildStep('GYP'):
    Run(['ninja', '-v'])

def AnalyzeLog(log_file):
  # pkg/fletchc/lib/src/driver/driver_main.dart will, in its log file, print
  # "1234: Crash (..." when an exception is thrown after shutting down a
  # client.  In this case, there's no obvious place to report the exception, so
  # the build bot must look for these crashes.
  pattern=re.compile(r"^[0-9]+: Crash \(")
  undiagnosed_crashes = False
  for line in log_file:
    if pattern.match(line):
      undiagnosed_crashes = True
      # For information about build bot annotations below, see
      # https://chromium.googlesource.com/chromium/tools/build/+/c63ec51491a8e47b724b5206a76f8b5e137ff1e7/scripts/master/chromium_step.py#472
      print '@@@STEP_LOG_LINE@undiagnosed_crashes@%s@@@' % line.rstrip()
  if undiagnosed_crashes:
    print '@@@STEP_LOG_END@undiagnosed_crashes@@@'
    MarkCurrentStep(fatal=True)

def ProcessFletchLog(fletch_log, debug_log):
  fletch_log.flush()
  fletch_log.seek(0)
  AnalyzeLog(fletch_log)
  fletch_log.seek(0)
  while True:
    buffer = fletch_log.read(1014*1024)
    if not buffer:
      break
    debug_log.write(buffer)

def StepBuild(build_config, build_dir, args=()):
  with bot.BuildStep('Build %s' % build_config):
    Run(['ninja', '-v', '-C', build_dir] + list(args))

def StepTest(
    name, mode, arch, clang=True, asan=False, snapshot_run=False,
    debug_log=None, configuration=None):
  step_name = '%s%s' % (name, '-snapshot' if snapshot_run else '')
  with bot.BuildStep('Test %s' % step_name, swallow_error=True):
    args = ['python', 'tools/test.py', '-m%s' % mode, '-a%s' % arch,
            '--time', '--report', '-pbuildbot',
            '--step_name=test_%s' % step_name,
            '--kill-persistent-process=0',
            '--run-gclient-hooks=0',
            '--build-before-testing=0',
            '--host-checked']
    if snapshot_run:
      # We let package:fletchc/fletchc.dart compile tests to snapshots.
      # Afterwards we run the snapshot with
      #  - normal fletch VM
      #  - fletch VM with -Xunfold-program enabled
      args.extend(['-cfletchc', '-rfletchvm'])

    if asan:
      args.append('--asan')

    if clang:
      args.append('--clang')

    with TemporaryHomeDirectory():
      with open(os.path.expanduser("~/.fletch.log"), 'w+') as fletch_log:
        # Use a new persistent daemon for every test run.
        # Append it's stdout/stderr to the "~/.fletch.log" file.
        try:
          with PersistentFletchDaemon(configuration, fletch_log):
            Run(args)
        finally:
          # Copy "~/.fletch.log" to ".debug.log" and look for crashes.
          ProcessFletchLog(fletch_log, debug_log)


#### Helper functionality

class PersistentFletchDaemon(object):
  def __init__(self, configuration, log_file):
    self._configuration = configuration
    self._log_file = log_file
    self._persistent = None

  def __enter__(self):
    print "Killing existing fletch processes"
    KillFletch(self._configuration['system'])

    print "Starting new persistent fletch daemon"
    self._persistent = subprocess.Popen(
      ['%s/dart' % self._configuration['build_dir'],
       '-c',
       '-p',
       './package/',
       'package:fletchc/src/driver/driver_main.dart',
       './.fletch'],
      stdout=self._log_file,
      stderr=subprocess.STDOUT,
      close_fds=True,
      # Launch the persistent process in a new process group. When shutting
      # down in response to a signal, the persistent process will kill its
      # process group to ensure that any processes it has spawned also exit. If
      # we don't use a new process group, that will also kill this process.
      preexec_fn=os.setsid)

  def __exit__(self, *_):
    print "Trying to wait for existing fletch daemon."
    self._persistent.terminate()
    self._persistent.wait()

    print "Killing existing fletch processes"
    KillFletch(self._configuration['system'])

class TemporaryHomeDirectory(object):
  """Creates a temporary directory and uses that as the home directory.

  This works by setting the environment variable HOME.
  """

  def __init__(self):
    self._old_home_dir = None
    self._tmp = None

  def __enter__(self):
    self._tmp = tempfile.mkdtemp()
    self._old_home_dir = os.getenv('HOME')
    # Note: os.putenv doesn't update os.environ, but assigning to os.environ
    # will also call putenv.
    os.environ['HOME'] = self._tmp

  def __exit__(self, *_):
    if self._old_home_dir:
      os.putenv('HOME', self._old_home_dir)
    else:
      os.unsetenv('HOME')
    shutil.rmtree(self._tmp)

def GetBuildConfigurations(system, modes, archs, asans):
  configurations = []

  for asan in asans:
    for mode in modes:
      for arch in archs:
        for compiler_variant in GetCompilerVariants(system, arch):
          build_conf = GetConfigurationName(mode, arch, compiler_variant, asan)
          configurations.append({
            'build_conf': build_conf,
            'build_dir': os.path.join('out', build_conf),
            'clang': bool(compiler_variant),
            'asan': asan,
            'mode': mode.lower(),
            'arch': arch.lower(),
            'system': system,
          })

  return configurations

def GetConfigurationName(mode, arch, compiler_variant='', asan=False):
  assert mode in ['release', 'debug']
  return '%(mode)s%(arch)s%(clang)s%(asan)s' % {
    'mode': 'Release' if mode == 'release' else 'Debug',
    'arch': arch.upper(),
    'clang': compiler_variant,
    'asan': 'Asan' if asan else '',
  }

def ShouldSkipConfiguration(snapshot_run, configuration):
  is_mac = configuration['system'] == 'mac'
  if is_mac and configuration['arch'] == 'x64' and configuration['asan']:
    # Asan/x64 takes a long time on mac.
    return True

  snapshot_run_configurations = ['DebugIA32', 'DebugIA32ClangAsan']
  if snapshot_run and (
     configuration['build_conf'] not in snapshot_run_configurations):
    # We only do full runs on DebugIA32 and DebugIA32ClangAsan for now.
    # snapshot_run = compile to snapshot &
    #                run shapshot &
    #                run shapshot with `-Xunfold-program`
    return True

  return False

def GetCompilerVariants(system, arch):
  is_mac = system == 'mac'
  is_arm = arch in ['arm', 'xarm']
  if is_mac:
    # gcc on mac is just an alias for clang.
    return ['Clang']
  elif is_arm:
    # We don't support cross compiling to arm with clang ATM.
    return ['']
  else:
    return ['', 'Clang']

def TarballName(arch, revision):
  return 'fletch_cross_build_%s_%s.tar.bz2' % (arch, revision)

def MarkCurrentStep(fatal=True):
  """Mark the current step as having a problem.

  If fatal is True, mark the current step as failed (red), otherwise mark it as
  having warnings (orange).
  """
  # See
  # https://chromium.googlesource.com/chromium/tools/build/+/c63ec51491a8e47b724b5206a76f8b5e137ff1e7/scripts/master/chromium_step.py#495
  if fatal:
    print '@@@STEP_FAILURE@@@'
  else:
    print '@@@STEP_WARNINGS@@@'
  sys.stdout.flush()

if __name__ == '__main__':
  # If main raises an exception we will get a very useful error message with
  # traceback written to stderr. We therefore intentionally do not catch
  # exceptions.
  Main()
