#!/usr/bin/python

# Copyright (c) 2014, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

"""
Buildbot steps for dartino testing
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
import dartino_namer

from os.path import dirname

utils = bot_utils.GetUtils()

DEBUG_LOG = ".debug.log"
FLAKY_LOG = ".flaky.log"
QEMU_LOG = ".qemu_log"
ALL_LOGS = [DEBUG_LOG, FLAKY_LOG, QEMU_LOG]

GCS_COREDUMP_BUCKET = 'dartino-buildbot-coredumps'

DARTINO_REGEXP = (r'dartino-'
                 r'(?P<system>linux|mac|win|lk|free-rtos)'
                 r'(?P<partial_configuration>'
                   r'-(?P<mode>debug|release)'
                   r'(?P<asan>-asan)?'
                   r'(?P<embedded_libs>-embedded-libs)?'
                   r'-(?P<architecture>x86|arm|x64|ia32)'
                 r')?'
                 r'(?P<sdk>-sdk)?')
CROSS_REGEXP = r'cross-dartino-(linux)-(arm)'
TARGET_REGEXP = r'target-dartino-(linux)-(debug|release)-(arm)'

DARTINO_PATH = dirname(dirname(dirname(os.path.abspath(__file__))))
GSUTIL = utils.GetBuildbotGSUtilPath()

GCS_BUCKET = 'gs://dartino-cross-compiled-binaries'

MACOS_NUMBER_OF_FILES = 10000

def Run(args):
  print "Running: %s" % ' '.join(args)
  sys.stdout.flush()
  bot.RunProcess(args)

def SetupClangEnvironment(system):
  if system != 'win32':
    os.environ['PATH'] = '%s/third_party/clang/%s/bin:%s' % (
        DARTINO_PATH, system, os.environ['PATH'])
  if system == 'macos':
    mac_library_path = "third_party/clang/mac/lib/clang/3.6.0/lib/darwin"
    os.environ['DYLD_LIBRARY_PATH'] = '%s/%s' % (DARTINO_PATH, mac_library_path)

def SetupJavaEnvironment(system):
  if system == 'macos':
    os.environ['JAVA_HOME'] = (
        '/Library/Java/JavaVirtualMachines/jdk1.7.0_71.jdk/Contents/Home')
  elif system == 'linux':
    os.environ['JAVA_HOME'] = '/usr/lib/jvm/java-7-openjdk-amd64'

def Main():
  name, _ = bot.GetBotName()

  dartino_match = re.match(DARTINO_REGEXP, name)
  cross_match = re.match(CROSS_REGEXP, name)
  target_match = re.match(TARGET_REGEXP, name)

  if not dartino_match and not cross_match and not target_match:
    raise Exception('Invalid buildername')

  SetupClangEnvironment(utils.GuessOS())
  SetupJavaEnvironment(utils.GuessOS())

  # Clobber build directory if the checkbox was pressed on the BB.
  with utils.ChangedWorkingDirectory(DARTINO_PATH):
    bot.Clobber()

  # Accumulate daemon logs messages in '.debug.log' to be displayed on the
  # buildbot.Log
  with utils.ChangedWorkingDirectory(DARTINO_PATH):
    StepsCleanLogs()
    with open(DEBUG_LOG, 'w') as debug_log:
      if dartino_match:
        system = dartino_match.group('system')
        if system == 'lk':
          StepsLK(debug_log)
        elif system == 'free-rtos':
          StepsFreeRtos(debug_log)
        else:
          modes = ['debug', 'release']
          archs = ['ia32', 'x64']
          asans = [False]
          embedded_libs = [False]

          # Split configurations?
          partial_configuration =\
            dartino_match.group('partial_configuration') != None
          if partial_configuration:
            architecture_match = dartino_match.group('architecture')
            archs = {
                'x86' : ['ia32', 'x64'],
                'x64' : ['x64'],
                'ia32' : ['ia32'],
            }[architecture_match]

            modes = [dartino_match.group('mode')]
            asans = [bool(dartino_match.group('asan'))]
            embedded_libs =[bool(dartino_match.group('embedded_libs'))]

          sdk_build = dartino_match.group('sdk')
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
  StepsShowLogs()
  return 1 if bot.HAS_FAILURES else 0

#### Buildbot steps

def StepsCleanLogs():
  with bot.BuildStep('Clean logs'):
    for log in ALL_LOGS:
      if os.path.exists(log):
        print 'Removing logfile: %s' % log
        os.remove(log)

def StepsShowLogs():
  for log in ALL_LOGS:
    if os.path.exists(log):
      with bot.BuildStep('Log %s' % log):
        with open(log) as f:
          print f.read()

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
  cross_archs = ['xarm', 'stm']
  cross_system = 'linux'
  # We only cross compile on linux
  if system == 'linux':
    StepsCreateDebianPackage()
    StepsArchiveDebianPackage()

    # We need the dartino daemon process to compile snapshots.
    for arch in ['ia32', 'x64']:
      host_configuration = GetBuildConfigurations(
        system=utils.GuessOS(),
        modes=['release'],
        archs=[arch],
        asans=[False],
        embedded_libs=[False],
        use_sdks=[False])[0]
      StepBuild(host_configuration['build_conf'],
                host_configuration['build_dir'])

    for cross_arch in cross_archs:
      CrossCompile(cross_system, [cross_mode], cross_arch)
      StepsArchiveCrossCompileBundle(cross_mode, cross_arch)
    StepsCreateArchiveRaspbianImge()
  elif system == 'mac':
    # We need the 32-bit build for the dartino-flashify program.
    if 'ia32' not in archs:
      ia32_configuration = GetBuildConfigurations(
        system=system,
        modes=['release'],
        archs=['ia32'],
        asans=[False],
        no_clang=no_clang,
        embedded_libs=embedded_libs,
        use_sdks=[True])[0]
      StepBuild(ia32_configuration['build_conf'],
                ia32_configuration['build_dir'])
    for cross_arch in cross_archs:
       StepsGetCrossBinaries(cross_mode, cross_arch)
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
  StepsArchiveOpenOCD(system)

def StepsTestSDK(debug_log, configuration):
  build_dir = configuration['build_dir']
  sdk_dir = os.path.join(build_dir, 'dartino-sdk')
  sdk_zip = os.path.join(build_dir, 'dartino-sdk.zip')
  if os.path.exists(sdk_dir):
    shutil.rmtree(sdk_dir)
  Unzip(sdk_zip)
  StepDisableAnalytics(os.path.join(sdk_dir, 'bin'))
  build_conf = configuration['build_conf']

  def run():
    StepTest(configuration=configuration,
        snapshot_run=False,
        debug_log=debug_log)

  RunWithCoreDumpArchiving(run, build_dir, build_conf)

def StepsSanityChecking(build_dir):
  version = utils.GetSemanticSDKVersion()
  sdk_dir = os.path.join(build_dir, 'dartino-sdk')
  bin_dir = os.path.join(sdk_dir, 'bin')
  StepDisableAnalytics(bin_dir)
  dartino = os.path.join(bin_dir, 'dartino')
  # TODO(ricow): we should test this as a normal test, see issue 232.
  dartino_version = subprocess.check_output([dartino, '--version']).strip()
  subprocess.check_call([dartino, 'quit'])
  if dartino_version != version:
    raise Exception('Version mismatch, VERSION file has %s, dartino has %s' %
                    (version, dartino_version))
  dartino_vm = os.path.join(build_dir, 'dartino-sdk', 'bin', 'dartino-vm')
  dartino_vm_version = subprocess.check_output([dartino_vm,
                                                '--version']).strip()
  if dartino_vm_version != version:
    raise Exception('Version mismatch, VERSION file has %s, dartino vm has %s' %
                    (version, dartino_vm_version))

def StepDisableAnalytics(bin_dir):
  with bot.BuildStep('Disable analytics'):
    dartino = os.path.join(bin_dir, 'dartino')
    try:
      print "%s disable analytics" % (dartino)
      print subprocess.check_output([dartino, 'disable', 'analytics'])
      print "Ensure background process is not running"
      print "%s quit" % (dartino)
      print subprocess.check_output([dartino, 'quit'])
    except Exception as error:
      print "Ignoring error: %s" % (error)

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
  return dartino_namer.DartinoGCSNamer(channel, temporary=temporary)

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
    sdk_docs = os.path.join(build_dir, 'dartino-sdk', 'docs')
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
    Run(['download_from_google_storage', '-b', 'dartino-dependencies',
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

def ArchiveThirdPartyTool(name, zip_name, system, gs_path):
  zip_file = os.path.join('out', zip_name)
  if os.path.exists(zip_file):
    os.remove(zip_file)
  copy = os.path.join('out', name)
  if os.path.exists(copy):
    shutil.rmtree(copy)
  src = os.path.join('third_party', name, system, name)
  shutil.copytree(src, copy)
  CreateZip(copy, zip_name)
  gsutil = bot_utils.GSUtil()
  gsutil.upload(zip_file, gs_path, public=True)
  http_path = GetDownloadLink(gs_path)
  print '@@@STEP_LINK@download@%s@@@' % http_path

def StepsArchiveGCCArmNoneEabi(system):
  with bot.BuildStep('Archive cross compiler'):
    # TODO(ricow): Early return on bleeding edge when this is validated.
    namer = GetNamer(temporary=IsBleedingEdge())
    version = utils.GetSemanticSDKVersion()
    ArchiveThirdPartyTool('gcc-arm-embedded',
                          namer.gcc_embedded_bundle_zipfilename(system),
                          system,
                          namer.gcc_embedded_bundle_filepath(version, system))

def StepsArchiveOpenOCD(system):
  with bot.BuildStep('Archive OpenOCD'):
    # TODO(ricow): Early return on bleeding edge when this is validated.
    namer = GetNamer(temporary=IsBleedingEdge())
    version = utils.GetSemanticSDKVersion()
    ArchiveThirdPartyTool('openocd',
                          namer.openocd_bundle_zipfilename(system),
                          system,
                          namer.openocd_bundle_filepath(version, system))

def StepsGetCrossBinaries(cross_mode, cross_arch):
  with bot.BuildStep('Get %s binaries %s' % (cross_arch, cross_mode)):
    build_conf = GetConfigurationName(cross_mode, cross_arch, '', False)
    build_dir = os.path.join('out', build_conf)
    version = utils.GetSemanticSDKVersion()
    gsutil = bot_utils.GSUtil()
    namer = GetNamer()
    zip_file = os.path.join(
      'out', namer.cross_binaries_zipfilename(cross_mode, cross_arch))
    if os.path.exists(zip_file):
      os.remove(zip_file)
    if os.path.exists(build_dir):
      shutil.rmtree(build_dir)
    gs_path = namer.cross_binaries_zipfilepath(version, cross_mode, cross_arch)
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
  with bot.BuildStep('Archive %s binaries %s' % (cross_arch, cross_mode)):
    build_conf = GetConfigurationName(cross_mode, cross_arch, '', False)
    version = utils.GetSemanticSDKVersion()
    namer = GetNamer()
    gsutil = bot_utils.GSUtil()
    zip_file = namer.cross_binaries_zipfilename(cross_mode, cross_arch)
    CreateZip(os.path.join('out', build_conf), zip_file)
    gs_path = namer.cross_binaries_zipfilepath(version, cross_mode, cross_arch)
    http_path = GetDownloadLink(gs_path)
    gsutil.upload(os.path.join('out', zip_file), gs_path, public=True)
    print '@@@STEP_LINK@download@%s@@@' % http_path


def StepsArchiveSDK(build_dir, system, mode, arch):
  with bot.BuildStep('Archive bundle %s' % build_dir):
    sdk = os.path.join(build_dir, 'dartino-sdk')
    zip_file = 'dartino-sdk.zip'
    CreateZip(sdk, zip_file)
    version = utils.GetSemanticSDKVersion()
    namer = GetNamer()
    gsutil = bot_utils.GSUtil()
    gs_path = namer.dartino_sdk_zipfilepath(version, system, arch, mode)
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
  args = ['dartino-vm'] if system == 'win' else ()

  # Build all necessary configurations.
  for configuration in configurations:
    StepBuild(configuration['build_conf'], configuration['build_dir'], args)

  StepDisableAnalytics(configuration['build_dir'])

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

  # We need the dartino daemon process to compile snapshots.
  for arch in ['ia32', 'x64']:
    host_configuration = GetBuildConfigurations(
      system=utils.GuessOS(),
      modes=['release'],
      archs=[arch],
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
  StepDisableAnalytics(host_configuration['build_dir'])

def StepsLK(debug_log):
  # We need the dartino daemon process to compile snapshots.
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

  StepDisableAnalytics(host_configuration['build_dir'])

  with bot.BuildStep('Test %s' % device_configuration['build_conf']):
    # TODO(ajohnsen): This is kind of funky, as test.py tries to start the
    # background process using -a and -m flags. We should maybe changed so
    # test.py can have both a host and target configuration.
    StepTest(
        configuration=device_configuration,
        debug_log=debug_log,
        snapshot_run=True)

  with bot.BuildStep('Test (heap blobs) %s' %
                     device_configuration['build_conf']):
    # TODO(ajohnsen): This is kind of funky, as test.py tries to start the
    # background process using -a and -m flags. We should maybe changed so
    # test.py can have both a host and target configuration.
    StepTest(
        configuration=device_configuration,
        debug_log=debug_log,
        use_heap_blob=True,
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
          assert os.path.exists(os.path.join(build_dir, 'dartino-vm'))

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
  # pkg/dartino_compiler/lib/src/hub/hub_main.dart will, in its log file, print
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

def ProcessDartinoLog(dartino_log, debug_log):
  dartino_log.flush()
  dartino_log.seek(0)
  AnalyzeLog(dartino_log)
  dartino_log.seek(0)
  while True:
    buffer = dartino_log.read(1014*1024)
    if not buffer:
      break
    debug_log.write(buffer)

def StepBuild(build_config, build_dir, args=()):
  with bot.BuildStep('Build %s' % build_config):
    Run(['ninja', '-v', '-C', build_dir] + list(args))

def StepTest(
    configuration=None,
    snapshot_run=False,
    use_heap_blob=False,
    debug_log=None):
  name = configuration['build_conf']
  mode = configuration['mode']
  arch = configuration['arch']
  asan = configuration['asan']
  clang = configuration['clang']
  system = configuration['system']
  embedded_libs = configuration['embedded_libs']
  use_sdk = configuration['use_sdk']

  if (use_heap_blob):
    suffix = '-heapblob'
  elif (snapshot_run):
    suffix = '-snapshot'
  else:
    suffix = ''
  step_name = '%s%s' % (name, suffix)

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
      # We let the dartino compiler compile tests to snapshots.
      # Afterwards we run the snapshot with
      #  - normal dartino VM
      #  - dartino VM with -Xunfold-program enabled
      args.extend(['-cdartino_compiler', '-rdartinovm'])

    if use_heap_blob:
      args.append('--use-heap-blob')

    if use_sdk:
      args.append('--use-sdk')

    if asan:
      args.append('--asan')

    if clang:
      args.append('--clang')

    if embedded_libs:
      args.append('--dartino-settings-file=embedded.dartino-settings')

    with TemporaryHomeDirectory():
      with open(os.path.expanduser("~/.dartino.log"), 'w+') as dartino_log:
        # Use a new persistent daemon for every test run.
        # Append it's stdout/stderr to the "~/.dartino.log" file.
        try:
          with PersistentDartinoDaemon(configuration, dartino_log):
            Run(args)
        finally:
          # Copy "~/.dartino.log" to ".debug.log" and look for crashes.
          ProcessDartinoLog(dartino_log, debug_log)


#### Helper functionality

class PersistentDartinoDaemon(object):
  def __init__(self, configuration, log_file):
    self._configuration = configuration
    self._log_file = log_file
    self._persistent = None

  def __enter__(self):
    print "Starting new persistent dartino daemon"
    version = utils.GetSemanticSDKVersion()
    dartinorc = os.path.join(os.path.abspath(os.environ['HOME']), '.dartino')
    self._persistent = subprocess.Popen(
      [os.path.join(os.path.abspath(self._configuration['build_dir']), 'dart'),
       '-c',
       '--packages=%s' % os.path.abspath('pkg/dartino_compiler/.packages'),
       '-Ddartino.version=%s' % version,
       'package:dartino_compiler/src/hub/hub_main.dart',
       dartinorc],
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
      # "dartino" program.
      print "Waiting for persistent process to start"
      time.sleep(0.5)
      self._log_file.seek(0, os.SEEK_END)

  def __exit__(self, *_):
    pid = self._persistent.pid
    print "Trying to wait for existing dartino daemon with pid: %s." % pid
    self._persistent.terminate()
    print "Exitcode from persistent process: %s" % self._persistent.wait()

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
      self._archive(os.path.join(self._build_dir, 'dartino'),
                    os.path.join(self._build_dir, 'dartino-vm'),
                    archive_coredumps)
      for filename in coredumps:
        print 'Removing core: %s' % filename
        os.remove(filename)
    coredumps = self._find_coredumps()
    assert not coredumps

  def _find_coredumps(self):
    # Finds all files named 'core.*' in the search directory.
    return glob.glob(os.path.join(self._search_dir, 'core.*'))

  def _archive(self, driver, dartino_vm, coredumps):
    assert coredumps
    files = [driver, dartino_vm] + coredumps

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
  is_stm = arch == 'stm'
  is_windows = system == 'win'
  if no_clang:
    return ['']
  elif is_mac:
    # gcc on mac is just an alias for clang.
    return ['Clang']
  elif is_arm:
    # We don't support cross compiling to arm with clang ATM.
    return ['']
  elif is_stm:
    # We don't support cross compiling to STM boards (Cortex-M7) with clang ATM.
    return ['']
  elif is_windows:
    # On windows we always use VC++.
    return ['']
  else:
    return ['', 'Clang']

def TarballName(arch, revision):
  return 'dartino_cross_build_%s_%s.tar.bz2' % (arch, revision)

def MarkCurrentStep(fatal=True):
  """Mark the current step as having a problem.

  If fatal is True, mark the current step as failed (red), otherwise mark it as
  having warnings (orange).
  """
  # See
  # https://chromium.googlesource.com/chromium/tools/build/+/c63ec51491a8e47b724b5206a76f8b5e137ff1e7/scripts/master/chromium_step.py#495
  if fatal:
    bot.HAS_FAILURES = True
    print '@@@STEP_FAILURE@@@'
  else:
    print '@@@STEP_WARNINGS@@@'
  sys.stdout.flush()

if __name__ == '__main__':
  # If main raises an exception we will get a very useful error message with
  # traceback written to stderr. We therefore intentionally do not catch
  # exceptions.
  sys.exit(Main())
