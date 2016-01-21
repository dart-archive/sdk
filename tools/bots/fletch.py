#!/usr/bin/python

# Copyright (c) 2014, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

"""
Buildbot steps for fletch testing
"""

import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

# The resource package does not exist on Windows but its functionality is not
# used there, either.
try:
  import resource
except ImportError:
  resource = None;

import bot
import bot_utils
import fletch_namer

from os.path import dirname

utils = bot_utils.GetUtils()

DEBUG_LOG=".debug.log"

GCS_COREDUMP_BUCKET = 'fletch-buildbot-coredumps'

FLETCH_REGEXP = (r'fletch-'
                 r'(?P<system>linux|mac|win|lk|free-rtos)'
                 r'(?P<partial_configuration>'
                   r'-(?P<mode>debug|release)'
                   r'(?P<asan>-asan)?'
                   r'(?P<embedded_libs>-embedded-libs)?'
                   r'-(?P<architecture>x86|arm|x64|ia32)'
                 r')?'
                 r'(?P<sdk>-sdk)?')
CROSS_REGEXP = r'cross-fletch-(linux)-(arm)'
TARGET_REGEXP = r'target-fletch-(linux)-(debug|release)-(arm)'

FLETCH_PATH = dirname(dirname(dirname(os.path.abspath(__file__))))
GSUTIL = utils.GetBuildbotGSUtilPath()

GCS_BUCKET = 'gs://fletch-cross-compiled-binaries'

MACOS_NUMBER_OF_FILES = 10000

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

def SetupJavaEnvironment(system):
  if system == 'macos':
    os.environ['JAVA_HOME'] = (
        '/Library/Java/JavaVirtualMachines/jdk1.7.0_71.jdk/Contents/Home')
  elif system == 'linux':
    os.environ['JAVA_HOME'] = '/usr/lib/jvm/java-7-openjdk-amd64'

def Main():
  name, _ = bot.GetBotName()

  fletch_match = re.match(FLETCH_REGEXP, name)
  cross_match = re.match(CROSS_REGEXP, name)
  target_match = re.match(TARGET_REGEXP, name)

  if not fletch_match and not cross_match and not target_match:
    raise Exception('Invalid buildername')

  SetupClangEnvironment(utils.GuessOS())
  SetupJavaEnvironment(utils.GuessOS())

  # Clobber build directory if the checkbox was pressed on the BB.
  with utils.ChangedWorkingDirectory(FLETCH_PATH):
    bot.Clobber()

  # Accumulate daemon logs messages in '.debug.log' to be displayed on the
  # buildbot.Log
  with open(DEBUG_LOG, 'w') as debug_log:
    with utils.ChangedWorkingDirectory(FLETCH_PATH):

      if fletch_match:
        system = fletch_match.group('system')

        if system == 'lk':
          StepsLK(debug_log)
          return

        if system == 'free-rtos':
          StepsFreeRtos(debug_log)
          return

        modes = ['debug', 'release']
        archs = ['ia32', 'x64']
        asans = [False]
        embedded_libs = [False]

        # Split configurations?
        partial_configuration =\
          fletch_match.group('partial_configuration') != None
        if partial_configuration:
          architecture_match = fletch_match.group('architecture')
          archs = {
              'x86' : ['ia32', 'x64'],
              'x64' : ['x64'],
              'ia32' : ['ia32'],
          }[architecture_match]

          modes = [fletch_match.group('mode')]
          asans = [bool(fletch_match.group('asan'))]
          embedded_libs =[bool(fletch_match.group('embedded_libs'))]

        sdk_build = fletch_match.group('sdk')
        if sdk_build:
          StepsSDK(debug_log, system, modes, archs, embedded_libs)
        else:
          StepsNormal(debug_log, system, modes, archs, asans, embedded_libs)
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

def StepsSDK(debug_log, system, modes, archs, embedded_libs):
  no_clang = system == 'linux'
  configurations = GetBuildConfigurations(
    system=system,
    modes=modes,
    archs=archs,
    asans=[False],
    no_clang=no_clang,
    embedded_libs=embedded_libs,
    use_sdks=[True])
  bot.Clobber(force=True)
  StepGyp()

  cross_mode = 'release'
  cross_arch = 'xarm'
  cross_system = 'linux'
  # We only cross compile on linux
  if system == 'linux':
    StepsCreateDebianPackage()
    StepsArchiveDebianPackage()
    CrossCompile(cross_system, [cross_mode], cross_arch)
    StepsArchiveCrossCompileBundle(cross_mode, cross_arch)
    StepsCreateArchiveRaspbianImge()
  elif system == 'mac':
     StepsGetArmBinaries(cross_mode, cross_arch)
     StepsGetArmDeb()
     # We currently only build documentation on linux.
     StepsGetDocs()
  for configuration in configurations:
    StepBuild(configuration['build_conf'], configuration['build_dir'])
    StepsBundleSDK(configuration['build_dir'], system)
    StepsArchiveSDK(configuration['build_dir'], system, configuration['mode'],
                    configuration['arch'])
  for configuration in configurations:
    StepsTestSDK(debug_log, configuration)
    StepsSanityChecking(configuration['build_dir'])
  StepsArchiveGCCArmNoneEabi(system)

def StepsTestSDK(debug_log, configuration):
  build_dir = configuration['build_dir']
  sdk_dir = os.path.join(build_dir, 'fletch-sdk')
  sdk_zip = os.path.join(build_dir, 'fletch-sdk.zip')
  if os.path.exists(sdk_dir):
    shutil.rmtree(sdk_dir)
  Unzip(sdk_zip)
  build_conf = configuration['build_conf']

  def run():
    StepTest(configuration=configuration,
        snapshot_run=False,
        debug_log=debug_log)

  RunWithCoreDumpArchiving(run, build_dir, build_conf)

def StepsSanityChecking(build_dir):
  version = utils.GetSemanticSDKVersion()
  fletch = os.path.join(build_dir, 'fletch-sdk', 'bin', 'fletch')
  # TODO(ricow): we should test this as a normal test, see issue 232.
  fletch_version = subprocess.check_output([fletch, '--version']).strip()
  subprocess.check_call([fletch, 'quit'])
  if fletch_version != version:
    raise Exception('Version mismatch, VERSION file has %s, fletch has %s' %
                    (version, fletch_version))
  fletch_vm = os.path.join(build_dir, 'fletch-sdk', 'bin', 'fletch-vm')
  fletch_vm_version = subprocess.check_output([fletch_vm, '--version']).strip()
  if fletch_vm_version != version:
    raise Exception('Version mismatch, VERSION file has %s, fletch vm has %s' %
                    (version, fletch_vm_version))

def StepsCreateDebianPackage():
  with bot.BuildStep('Create arm agent deb'):
    Run(['python', os.path.join('tools', 'create_tarball.py')])
    Run(['python', os.path.join('tools', 'create_debian_packages.py')])

def StepsArchiveDebianPackage():
  with bot.BuildStep('Archive arm agent deb'):
    version = utils.GetSemanticSDKVersion()
    namer = GetNamer()
    gsutil = bot_utils.GSUtil()
    deb_file = os.path.join('out', namer.arm_agent_filename(version))
    gs_path = namer.arm_agent_filepath(version)
    http_path = GetDownloadLink(gs_path)
    gsutil.upload(deb_file, gs_path, public=True)
    print '@@@STEP_LINK@download@%s@@@' % http_path

def GetDownloadLink(gs_path):
  return gs_path.replace('gs://', 'https://storage.googleapis.com/')

def GetNamer(temporary=False):
  name, _ = bot.GetBotName()
  channel = bot_utils.GetChannelFromName(name)
  return fletch_namer.FletchGCSNamer(channel, temporary=temporary)

def IsBleedingEdge():
  name, _ = bot.GetBotName()
  channel = bot_utils.GetChannelFromName(name)
  return channel == bot_utils.Channel.BLEEDING_EDGE

def StepsBundleSDK(build_dir, system):
  with bot.BuildStep('Bundle sdk %s' % build_dir):
    version = utils.GetSemanticSDKVersion()
    namer = GetNamer()
    deb_file = os.path.join('out', namer.arm_agent_filename(version))
    create_docs = '--create_documentation' if system == 'linux' else ''
    Run(['tools/bundle_sdk.py', '--build_dir=%s' % build_dir,
         '--deb_package=%s' % deb_file, create_docs])
    # On linux this is build in the step above, on mac this is fetched from
    # cloud storage.
    sdk_docs = os.path.join(build_dir, 'fletch-sdk', 'docs')
    shutil.copytree(os.path.join('out', 'docs'), sdk_docs)

def CreateZip(directory, target_file):
  with utils.ChangedWorkingDirectory(os.path.dirname(directory)):
    if os.path.exists(target_file):
      os.remove(target_file)
    command = ['zip', '-yrq9', target_file, os.path.basename(directory)]
    Run(command)

def Unzip(zip_file):
  with utils.ChangedWorkingDirectory(os.path.dirname(zip_file)):
    Run(['unzip', os.path.basename(zip_file)])

def EnsureRaspbianBase():
  with bot.BuildStep('Ensure raspbian base image and kernel'):
    Run(['download_from_google_storage', '-b', 'dart-dependencies-fletch',
         '-u', '-d', 'third_party/raspbian/'])

def StepsCreateArchiveRaspbianImge():
  EnsureRaspbianBase()
  with bot.BuildStep('Modifying raspbian image'):
    namer = GetNamer(temporary=IsBleedingEdge())
    raspbian_src = os.path.join('third_party', 'raspbian', 'image',
                                'jessie.img')
    raspbian_dst = os.path.join('out', namer.raspbian_filename())
    print 'Copying %s to %s' % (raspbian_src, raspbian_dst)
    shutil.copyfile(raspbian_src, raspbian_dst)
    version = utils.GetSemanticSDKVersion()
    deb_file = os.path.join('out', namer.arm_agent_filename(version))
    src_file = os.path.join('out', namer.src_tar_name(version))
    Run(['tools/raspberry-pi2/raspbian_prepare.py',
         '--image=%s' % raspbian_dst,
         '--agent=%s' % deb_file,
         '--src=%s' % src_file])
    zip_file = os.path.join('out', namer.raspbian_zipfilename())
    if os.path.exists(zip_file):
      os.remove(zip_file)
    CreateZip(raspbian_dst, namer.raspbian_zipfilename())
    gsutil = bot_utils.GSUtil()
    gs_path = namer.raspbian_zipfilepath(version)
    http_path = GetDownloadLink(gs_path)
    gsutil.upload(zip_file, gs_path, public=True)
    print '@@@STEP_LINK@download@%s@@@' % http_path

def StepsArchiveGCCArmNoneEabi(system):
  with bot.BuildStep('Archive cross compiler'):
    # TODO(ricow): Early return on bleeding edge when this is validated.
    namer = GetNamer(temporary=IsBleedingEdge())
    zip_file = os.path.join('out',
                            namer.gcc_embedded_bundle_zipfilename(system))
    if os.path.exists(zip_file):
      os.remove(zip_file)
    gcc_copy = os.path.join('out', 'gcc-arm-embedded')
    if os.path.exists(gcc_copy):
      shutil.rmtree(gcc_copy)
    gcc_src = os.path.join('third_party', 'gcc-arm-embedded', system,
                           'gcc-arm-embedded')
    shutil.copytree(gcc_src, gcc_copy)
    CreateZip(gcc_copy, namer.gcc_embedded_bundle_zipfilename(system))
    version = utils.GetSemanticSDKVersion()
    gsutil = bot_utils.GSUtil()
    gs_path = namer.gcc_embedded_bundle_filepath(version, system)
    gsutil.upload(zip_file, gs_path, public=True)
    http_path = GetDownloadLink(gs_path)
    print '@@@STEP_LINK@download@%s@@@' % http_path

def StepsGetArmBinaries(cross_mode, cross_arch):
  with bot.BuildStep('Get arm binaries %s' % cross_mode):
    build_conf = GetConfigurationName(cross_mode, cross_arch, '', False)
    build_dir = os.path.join('out', build_conf)
    version = utils.GetSemanticSDKVersion()
    gsutil = bot_utils.GSUtil()
    namer = GetNamer()
    zip_file = os.path.join('out', namer.arm_binaries_zipfilename(cross_mode))
    if os.path.exists(zip_file):
      os.remove(zip_file)
    if os.path.exists(build_dir):
      shutil.rmtree(build_dir)
    gs_path = namer.arm_binaries_zipfilepath(version, cross_mode)
    gsutil.execute(['cp', gs_path, zip_file])
    Unzip(zip_file)

def StepsGetArmDeb():
  with bot.BuildStep('Get agent deb'):
    version = utils.GetSemanticSDKVersion()
    gsutil = bot_utils.GSUtil()
    namer = GetNamer()
    deb_file = os.path.join('out', namer.arm_agent_filename(version))
    gs_path = namer.arm_agent_filepath(version)
    if os.path.exists(deb_file):
      os.remove(deb_file)
    gsutil.execute(['cp', gs_path, deb_file])

def StepsGetDocs():
  with bot.BuildStep('Get docs'):
    version = utils.GetSemanticSDKVersion()
    gsutil = bot_utils.GSUtil()
    namer = GetNamer()
    docs_out = os.path.join('out')
    gs_path = namer.docs_filepath(version)
    gsutil.execute(['-m', 'cp', '-r', gs_path, docs_out])

def StepsArchiveCrossCompileBundle(cross_mode, cross_arch):
  with bot.BuildStep('Archive arm binaries %s' % cross_mode):
    build_conf = GetConfigurationName(cross_mode, cross_arch, '', False)
    version = utils.GetSemanticSDKVersion()
    namer = GetNamer()
    gsutil = bot_utils.GSUtil()
    zip_file = namer.arm_binaries_zipfilename(cross_mode)
    CreateZip(os.path.join('out', build_conf), zip_file)
    gs_path = namer.arm_binaries_zipfilepath(version, cross_mode)
    http_path = GetDownloadLink(gs_path)
    gsutil.upload(os.path.join('out', zip_file), gs_path, public=True)
    print '@@@STEP_LINK@download@%s@@@' % http_path


def StepsArchiveSDK(build_dir, system, mode, arch):
  with bot.BuildStep('Archive bundle %s' % build_dir):
    sdk = os.path.join(build_dir, 'fletch-sdk')
    zip_file = 'fletch-sdk.zip'
    CreateZip(sdk, zip_file)
    version = utils.GetSemanticSDKVersion()
    namer = GetNamer()
    gsutil = bot_utils.GSUtil()
    gs_path = namer.fletch_sdk_zipfilepath(version, system, arch, mode)
    http_path = GetDownloadLink(gs_path)
    gsutil.upload(os.path.join(build_dir, zip_file), gs_path, public=True)
    print '@@@STEP_LINK@download@%s@@@' % http_path
    docs_gs_path = namer.docs_filepath(version)
    gsutil.upload(os.path.join('out', 'docs'), docs_gs_path, recursive=True,
                  public=True)
    docs_http_path = '%s/%s' % (GetDownloadLink(docs_gs_path), 'index.html')
    print '@@@STEP_LINK@docs@%s@@@' % docs_http_path

def StepsNormal(debug_log, system, modes, archs, asans, embedded_libs):
  # TODO(herhut): Remove once Windows port is complete.
  archs = ['ia32'] if system == 'win' else archs

  configurations = GetBuildConfigurations(
      system=system,
      modes=modes,
      archs=archs,
      asans=asans,
      embedded_libs=embedded_libs,
      use_sdks=[False])

  # Generate ninja files.
  StepGyp()

  # TODO(herhut): Remove once Windows port is complete.
  args = ['libfletch'] if system == 'win' else ()

  # Build all necessary configurations.
  for configuration in configurations:
    StepBuild(configuration['build_conf'], configuration['build_dir'], args)

  # TODO(herhut): Remove once Windows port is complete.
  if system == 'win':
    return

  # Run tests on all necessary configurations.
  for snapshot_run in [True, False]:
    for configuration in configurations:
      if not ShouldSkipConfiguration(snapshot_run, configuration):
        build_conf = configuration['build_conf']
        build_dir = configuration['build_dir']

        def run():
          StepTest(
              configuration=configuration,
              snapshot_run=snapshot_run,
              debug_log=debug_log)

        RunWithCoreDumpArchiving(run, build_dir, build_conf)

def StepsFreeRtos(debug_log):
  StepGyp()

  # We need the fletch daemon process to compile snapshots.
  host_configuration = GetBuildConfigurations(
      system=utils.GuessOS(),
      modes=['release'],
      archs=['x64'],
      asans=[False],
      embedded_libs=[False],
      use_sdks=[False])[0]
  StepBuild(host_configuration['build_conf'], host_configuration['build_dir'])

  configuration = GetBuildConfigurations(
      system=utils.GuessOS(),
      modes=['debug'],
      archs=['STM'],
      asans=[False],
      embedded_libs=[False],
      use_sdks=[False])[0]
  StepBuild(configuration['build_conf'], configuration['build_dir'])


def StepsLK(debug_log):
  # We need the fletch daemon process to compile snapshots.
  host_configuration = GetBuildConfigurations(
      system=utils.GuessOS(),
      modes=['debug'],
      archs=['ia32'],
      asans=[False],
      embedded_libs=[False],
      use_sdks=[False])[0]

  # Generate ninja files.
  StepGyp()

  StepBuild(host_configuration['build_conf'], host_configuration['build_dir'])

  device_configuration = host_configuration.copy()

  device_configuration['build_conf'] = 'DebugLK'
  device_configuration['system'] = 'lk'

  with bot.BuildStep('Build %s' % device_configuration['build_conf']):
    Run(['make', '-C', 'third_party/lk', 'clean'])
    Run(['make', '-C', 'third_party/lk', '-j8'])

  with bot.BuildStep('Test %s' % device_configuration['build_conf']):
    # TODO(ajohnsen): This is kind of funky, as test.py tries to start the
    # background process using -a and -m flags. We should maybe changed so
    # test.py can have both a host and target configuration.
    StepTest(
        configuration=device_configuration,
        debug_log=debug_log,
        snapshot_run=True)

def StepsCrossBuilder(debug_log, system, modes, arch):
  """This step builds XARM configurations and archives the results.

  The buildbot will trigger a build to run this cross builder. After it has
  built and archived build artifacts, the buildbot master will schedule a build
  for running the actual tests on a ARM device. The triggered build will
  eventually invoke the `StepsTargetRunner` function defined blow, which will
  take care of downloading/extracting the build artifacts and executing tests.
  """

  revision = os.environ.get('BUILDBOT_GOT_REVISION', '42')
  assert revision

  CrossCompile(system, modes, arch)

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

def CrossCompile(system, modes, arch):
  for compiler_variant in GetCompilerVariants(system, arch):
    for mode in modes:
      build_conf = GetConfigurationName(mode, arch, compiler_variant, False)
      StepBuild(build_conf, os.path.join('out', build_conf))

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
    configurations = GetBuildConfigurations(
      system=system,
      modes=[mode],
      archs=[arch],
      asans=[False],
      embedded_libs=[False],
      use_sdks=[False])
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

          def run():
            StepTest(
              configuration=configuration,
              snapshot_run=snapshot_run,
              debug_log=debug_log)

          #RunWithCoreDumpArchiving(run, build_dir, build_conf)
          run()
  finally:
    if os.path.exists(tarball):
      os.remove(tarball)

    # We always clobber this to save disk on the arm board.
    bot.Clobber(force=True)


#### Buildbot steps helper

def StepGyp():
  with bot.BuildStep('GYP'):
    Run(['python', 'tools/run-ninja.py', '-v'])

def AnalyzeLog(log_file):
  # pkg/fletchc/lib/src/hub/hub_main.dart will, in its log file, print
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
    configuration=None,
    snapshot_run=False,
    debug_log=None):
  name = configuration['build_conf']
  mode = configuration['mode']
  arch = configuration['arch']
  asan = configuration['asan']
  clang = configuration['clang']
  system = configuration['system']
  embedded_libs = configuration['embedded_libs']
  use_sdk = configuration['use_sdk']

  step_name = '%s%s' % (name, '-snapshot' if snapshot_run else '')
  with bot.BuildStep('Test %s' % step_name, swallow_error=True):
    args = ['python', 'tools/test.py', '-m%s' % mode, '-a%s' % arch,
            '--time', '--report', '-pbuildbot',
            '--step_name=test_%s' % step_name,
            '--kill-persistent-process=0',
            '--run-gclient-hooks=0',
            '--build-before-testing=0',
            '--host-checked']

    if system:
      system_argument = 'macos' if system == 'mac' else system
      args.append('-s%s' % system_argument)

    if snapshot_run:
      # We let the fletch compiler compile tests to snapshots.
      # Afterwards we run the snapshot with
      #  - normal fletch VM
      #  - fletch VM with -Xunfold-program enabled
      args.extend(['-cfletchc', '-rfletchvm'])

    if use_sdk:
      args.append('--use-sdk')

    if asan:
      args.append('--asan')

    if clang:
      args.append('--clang')

    if embedded_libs:
      args.append('--fletch-settings-file=embedded.fletch-settings')

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
    print "Starting new persistent fletch daemon"
    version = utils.GetSemanticSDKVersion()
    fletchrc = os.path.join(os.path.abspath(os.environ['HOME']), '.fletch')
    self._persistent = subprocess.Popen(
      [os.path.join(os.path.abspath(self._configuration['build_dir']), 'dart'),
       '-c',
       # TODO(kustermann): Issue(396): Remove this --enable-dumpcore flag again.
       '--enable-dumpcore',
       '--packages=%s' % os.path.abspath('pkg/fletchc/.packages'),
       '-Dfletch.version=%s' % version,
       'package:fletchc/src/hub/hub_main.dart',
       fletchrc],
      stdout=self._log_file,
      stderr=subprocess.STDOUT,
      close_fds=True,
      # Launch the persistent process in a new process group. When shutting
      # down in response to a signal, the persistent process will kill its
      # process group to ensure that any processes it has spawned also exit. If
      # we don't use a new process group, that will also kill this process.
      preexec_fn=os.setsid
      # TODO(kustermann): Issue(396): Make the cwd=/ again.
      ## We change the current directory of the persistent process to ensure
      ## that we read files relative to the C++ client's current directory, not
      ## the persistent process'.
      #, cwd='/')
      )

    while not self._log_file.tell():
      # We're waiting for the persistent process to write a line on stdout. It
      # always does so as it is part of a handshake when started by the
      # "fletch" program.
      print "Waiting for persistent process to start"
      time.sleep(0.5)
      self._log_file.seek(0, os.SEEK_END)

  def __exit__(self, *_):
    print "Trying to wait for existing fletch daemon."
    self._persistent.terminate()
    self._persistent.wait()

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
      os.environ['HOME'] = self._old_home_dir
    else:
      del os.environ['HOME']
    shutil.rmtree(self._tmp)

class CoredumpEnabler(object):
  def __init__(self):
    self._old_limits = None

  def __enter__(self):
    self._old_limits = resource.getrlimit(resource.RLIMIT_CORE)
    resource.setrlimit(resource.RLIMIT_CORE, (-1, -1))

  def __exit__(self, *_):
    resource.setrlimit(resource.RLIMIT_CORE, self._old_limits)

class CoredumpArchiver(object):
  def __init__(self, search_dir, bucket, build_dir, conf):
    self._search_dir = search_dir
    self._bucket = bucket
    self._build_dir = build_dir
    self._conf = conf

  def __enter__(self):
    coredumps = self._find_coredumps()
    assert not coredumps

  def __exit__(self, *_):
    coredumps = self._find_coredumps()
    if coredumps:
      # If we get a ton of crashes, only archive 10 dumps.
      archive_coredumps = coredumps[:10]
      print 'Archiving coredumps: %s' % ', '.join(archive_coredumps)
      sys.stdout.flush()
      self._archive(os.path.join(self._build_dir, 'fletch'),
                    os.path.join(self._build_dir, 'fletch-vm'),
                    archive_coredumps)
      for filename in coredumps:
        print 'Removing core: %s' % filename
        os.remove(filename)
    coredumps = self._find_coredumps()
    assert not coredumps

  def _find_coredumps(self):
    # Finds all files named 'core.*' in the search directory.
    return glob.glob(os.path.join(self._search_dir, 'core.*'))

  def _archive(self, driver, fletch_vm, coredumps):
    assert coredumps
    files = [driver, fletch_vm] + coredumps

    for filename in files:
      assert os.path.exists(filename)

    gsutil = bot_utils.GSUtil()
    storage_path = '%s/%s/' % (self._bucket, uuid.uuid4())
    gs_prefix = 'gs://%s' % storage_path
    http_prefix = 'https://storage.cloud.google.com/%s' % storage_path

    for filename in files:
      # Remove / from absolute path to not have // in gs path.
      gs_url = '%s%s' % (gs_prefix, filename.lstrip('/'))
      http_url = '%s%s' % (http_prefix, filename.lstrip('/'))

      try:
        gsutil.upload(filename, gs_url)
        print '@@@STEP_LOG_LINE@coredumps@%s (%s)@@@' % (gs_url, http_url)
      except Exception as error:
        message = "Failed to upload coredump %s, error: %s" % (filename, error)
        print '@@@STEP_LOG_LINE@coredumps@%s@@@' % message

    print '@@@STEP_LOG_END@coredumps@@@'
    MarkCurrentStep(fatal=False)

class IncreasedNumberOfFiles(object):
  def __init__(self, count):
    self._old_limits = None
    self._limits = (count, count)

  def __enter__(self):
    self._old_limits = resource.getrlimit(resource.RLIMIT_NOFILE)
    print "IncreasedNumberOfFiles: Old limits were:", self._old_limits
    print "IncreasedNumberOfFiles: Setting to:", self._limits
    resource.setrlimit(resource.RLIMIT_NOFILE, self._limits)

  def __exit__(self, *_):
    print "IncreasedNumberOfFiles: Restoring to:", self._old_limits
    try:
      resource.setrlimit(resource.RLIMIT_NOFILE, self._old_limits)
    except ValueError:
      print "IncreasedNumberOfFiles: Could not restore to:", self._old_limits

class LinuxCoredumpArchiver(CoredumpArchiver):
  def __init__(self, *args):
    super(LinuxCoredumpArchiver, self).__init__(os.getcwd(), *args)

  def __enter__(self):
    super(LinuxCoredumpArchiver, self).__enter__()

    core_pattern_file = '/proc/sys/kernel/core_pattern'
    core_pattern = open(core_pattern_file).read()
    core_pattern_uses_pid_file = '/proc/sys/kernel/core_uses_pid'
    core_pattern_uses_pid = open(core_pattern_uses_pid_file).read()

    expected_core_pattern = 'core'
    expected_core_pattern_uses_pid = '1'
    if (core_pattern.strip() != expected_core_pattern or
        core_pattern_uses_pid.strip() != expected_core_pattern_uses_pid):
      message = ("Invalid core_pattern and/or core_uses_pid configuration. "
          "The configuration of core dump handling is *not* correct for "
          "a buildbot. The content of {0} must be '{1}' and the content "
          "of {2} must be '{3}'."
          .format(core_pattern_file, expected_core_pattern,
                  core_pattern_uses_pid_file, expected_core_pattern_uses_pid))
      raise Exception(message)

class MacosCoredumpArchiver(CoredumpArchiver):
  def __init__(self, *args):
    super(MacosCoredumpArchiver, self).__init__('/cores', *args)

  def __enter__(self):
    super(MacosCoredumpArchiver, self).__enter__()

    assert os.path.exists(self._search_dir)

def RunWithCoreDumpArchiving(run, build_dir, build_conf):
  guessed_os = utils.GuessOS()
  if guessed_os == 'linux':
    with CoredumpEnabler():
      with LinuxCoredumpArchiver(GCS_COREDUMP_BUCKET, build_dir, build_conf):
        run()
  elif guessed_os == 'macos':
    with IncreasedNumberOfFiles(MACOS_NUMBER_OF_FILES):
      with CoredumpEnabler():
        with MacosCoredumpArchiver(GCS_COREDUMP_BUCKET, build_dir, build_conf):
          run()
  else:
    run()

def GetBuildConfigurations(
        system=None,
        modes=None,
        archs=None,
        asans=None,
        no_clang=False,
        embedded_libs=None,
        use_sdks=None):
  configurations = []

  for asan in asans:
    for mode in modes:
      for arch in archs:
        for compiler_variant in GetCompilerVariants(system, arch, no_clang):
          for embedded_lib in embedded_libs:
            for use_sdk in use_sdks:
              build_conf = GetConfigurationName(
                  mode, arch, compiler_variant, asan)
              configurations.append({
                'build_conf': build_conf,
                'build_dir': os.path.join('out', build_conf),
                'clang': bool(compiler_variant),
                'asan': asan,
                'mode': mode.lower(),
                'arch': arch.lower(),
                'system': system,
                'embedded_libs': embedded_lib,
                'use_sdk': use_sdk
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

def GetCompilerVariants(system, arch, no_clang=False):
  is_mac = system == 'mac'
  is_arm = arch in ['arm', 'xarm']
  is_windows = system == 'win'
  if no_clang:
    return ['']
  elif is_mac:
    # gcc on mac is just an alias for clang.
    return ['Clang']
  elif is_arm:
    # We don't support cross compiling to arm with clang ATM.
    return ['']
  elif is_windows:
    # On windows we always use VC++.
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
