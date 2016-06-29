#!/usr/bin/env python
# Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# This script is creating a self contained directory with all the tools,
# libraries, packages and samples needed for running Dartino.

# This script assumes that the target architecture has been build in the passed
# in --build_dir and that the corresponding 32-bit architecture is also.
# Finally it also assumes that out/ReleaseXARM/dartino-vm, out/ReleaseSTM
# and out/ReleaseCM4 have been build.

import optparse
import subprocess
import sys
import utils
import re

from sets import Set
from os import makedirs, listdir
from os.path import dirname, join, exists, basename, abspath
from shutil import copyfile, copymode, copytree, rmtree, ignore_patterns
from fnmatch import fnmatch

TOOLS_DIR = abspath(dirname(__file__))

SAMPLES = ['general', 'raspberry-pi2', 'stm32f746g-discovery',
           'stm32f411re-nucleo']

def ParseOptions():
  parser = optparse.OptionParser()
  parser.add_option("--build_dir")
  parser.add_option("--deb_package")
  parser.add_option("--create_documentation", default=False,
                    action="store_true")
  parser.add_option("--include_tools", default=False, action="store_true")
  (options, args) = parser.parse_args()
  return options

def CopyFile(src, dst):
  copyfile(src, dst)
  copymode(src, dst)

def EnsureDeleted(directory):
  if exists(directory):
    rmtree(directory)
  if exists(directory):
    raise Exception("Could not delete %s" % directory)

def BuildDir32(build_dir):
  return build_dir.replace('X64', 'IA32')

def CopySharedLibraries(bin_dir, build_dir):
  shared_libraries = ['mbedtls']
  # Libraries are placed differently on mac and linux:
  # Linux has lib/libNAME.so
  # Mac has libNAME.dylib
  os_name = utils.GuessOS()
  lib_dst = join(bin_dir, 'lib') if os_name == 'linux' else bin_dir
  lib_src = join(build_dir, 'lib') if os_name == 'linux' else build_dir
  suffix = 'so' if os_name == 'linux' else 'dylib'
  if os_name == 'linux':
    makedirs(lib_dst)
  for lib in shared_libraries:
    lib_name = 'lib%s.%s' % (lib, suffix)
    src = join(lib_src, lib_name)
    dst = join(lib_dst, lib_name)
    CopyFile(src, dst)

def CopyBinaries(bundle_dir, build_dir):
  bin_dir = join(bundle_dir, 'bin')
  internal = join(bundle_dir, 'internal')
  makedirs(bin_dir)
  makedirs(internal)
  # Copy the dartino VM.
  CopyFile(join(build_dir, 'dartino-vm'), join(bin_dir, 'dartino-vm'))
  # Copy the 32-bit version of dartino-flashify.
  CopyFile(join(BuildDir32(build_dir), 'dartino-flashify'),
           join(bin_dir, 'dartino-flashify'))
  # The driver for the sdk is specially named dartino_for_sdk.
  CopyFile(join(build_dir, 'dartino_for_sdk'), join(bin_dir, 'dartino'))
  # We move the dart vm to internal to not put it on the path of users
  CopyFile(join(build_dir, 'dart'), join(internal, 'dart'))
  # natives.json is read relative to the dart binary
  CopyFile(join(build_dir, 'natives.json'), join(internal, 'natives.json'))
  CopySharedLibraries(bin_dir, build_dir)

def ThirdPartyDartSdkDir():
  os_name = utils.GuessOS()
  if os_name == "macos":
    os_name = "mac"
  return join('third_party', 'dart-sdk', os_name, 'dart-sdk')

def CopyDartSdk(bundle_dir):
  source = ThirdPartyDartSdkDir()
  target = join(bundle_dir, 'internal', 'dart-sdk')
  print 'copying %s to %s' % (source, target)
  copytree(source, target)

# Copy the platform decriptor, rewriting paths to point to the
# sdk location at `sdk_dir` instead of `repo_dir`.
def CopyPlatformDescriptor(bundle_dir, platform_descriptor_name, repo_dir,
                           sdk_dir):
  platform_path = join('lib', platform_descriptor_name)
  with open(platform_path) as f:
    lines = f.read().splitlines()
  dest = join(bundle_dir, 'internal', 'dartino_lib', platform_descriptor_name)
  print("Copying from %s to %s adjusting paths." % (platform_path, dest))
  with open(dest, 'w') as generated:
    for line in lines:
      if line.startswith('#') or line.startswith('['):
        pass
      else:
        # The property-lines consist of name:uri. The uri can
        # contain a ':' so we only split at the first ':'.
        parts = line.split(':', 1)
        if len(parts) == 2:
          name, path = parts
          path = path.strip()
          if path.startswith(repo_dir):
            # Dart-sdk library
            path = path.replace(repo_dir, sdk_dir)
          line = "%s: %s" % (name, path)
      generated.write('%s\n' % line)

# We have two lib dependencies: the libs from the sdk and the libs dir with
# patch files from the dartino repo.
def CopyLibs(bundle_dir, build_dir):
  internal = join(bundle_dir, 'internal')
  dartino_lib = join(internal, 'dartino_lib')
  dart_lib = join(internal, 'dart_lib')
  copytree('lib', dartino_lib)
  copytree('third_party/dart/sdk/lib', dart_lib)
  CopyPlatformDescriptor(bundle_dir, 'dartino_mobile.platform',
                         '../third_party/dart/sdk/lib', '../dart_lib')
  CopyPlatformDescriptor(bundle_dir, 'dartino_embedded.platform',
                         '../third_party/dart/sdk/lib', '../dart_lib')

def CopyInclude(bundle_dir):
  include = join(bundle_dir, 'include')
  copytree('include', include)

def CopyInternalPackages(bundle_dir, build_dir):
  internal_pkg = join(bundle_dir, 'internal', 'pkg')
  makedirs(internal_pkg)
  # Copy the pkg dirs for tools and the pkg dirs referred from their
  # .packages files.
  copied_pkgs = Set()
  for tool in ['dartino_compiler', 'flash_sd_card']:
    copytree(join('pkg', tool), join(internal_pkg, tool))
    tool_pkg = 'pkg/%s' % tool
    fixed_packages_file = join(internal_pkg, tool, '.packages')
    lines = []
    with open(join(tool_pkg, '.packages')) as f:
      lines = f.read().splitlines()
    with open(fixed_packages_file, 'w') as generated:
      for l in lines:
        if l.startswith('#') or l.startswith('%s:lib' % tool):
          generated.write('%s\n' % l)
        else:
          components = l.split(':')
          name = components[0]
          relative_path = components[1]
          source = join(tool_pkg, relative_path)
          target = join(internal_pkg, name)
          print source
          if not target in copied_pkgs:
            print 'copying %s to %s' % (source, target)
            makedirs(target)
            assert(source.endswith('lib'))
            copytree(source, join(target, 'lib'))
            copied_pkgs.add(target)
          generated.write('%s:../%s/lib\n' % (name, name))

def CopyPackagesAndSettingsTemplate(bundle_dir):
  target_dir = join(bundle_dir, 'pkg')
  makedirs(target_dir)
  copyfile(join('pkg', 'dartino_sdk_dartino_settings'),
           join(bundle_dir, 'internal', '.dartino-settings'))

  # Read the pkg/dartino-sdk.packages file
  # and generate internal/dartino-sdk.packages
  with open(join('pkg', 'dartino-sdk.packages')) as f:
    lines = f.read().splitlines()
  with open(join(bundle_dir, 'internal', 'dartino-sdk.packages'), 'w') as f:
    for line in lines:
      parts = line.split(':')
      name, path = parts
      copytree(join('pkg', path, '..'), join(target_dir, name))
      line = "%s:../pkg/%s/lib" % (name, name)
      f.write('%s\n' % line)

  # Update the dartino_lib/dartino/lib/_embedder.yaml file
  # based upon the SDK structure
  embedderPath = join(target_dir, 'dartino', 'lib', '_embedder.yaml')
  with open(embedderPath) as f:
    s = f.read()
  s = s.replace('../../../lib/',
                '../../../internal/dartino_lib/')
  s = s.replace('../../../third_party/dart/sdk/lib/',
                '../../../internal/dart_lib/')
  with open(embedderPath, 'w') as f:
    f.write(s)

def CopyPlatforms(bundle_dir):
  # Only copy parts of the platforms directory. We also have source
  # code there at the moment.
  target_platforms_dir = join(bundle_dir, 'platforms')
  for platforms_dir in [
      'bin', 'raspberry-pi2', 'stm32f746g-discovery', 'stm32f411re-nucleo']:
    copytree(join('platforms', platforms_dir),
             join(target_platforms_dir, platforms_dir))

def CreateSnapshot(dart_executable, dart_file, snapshot):
  # TODO(karlklose): Run 'build_dir/dartino export' instead?
  cmd = [dart_executable, '-c', '--packages=pkg/dartino_compiler/.packages',
         '-Dsnapshot="%s"' % snapshot,
         '-Dpackages=".packages"',
         '-Dtest.dartino_settings_file_name=".dartino-settings"',
         'tests/dartino_compiler/run.dart', dart_file]
  print 'Running %s' % ' '.join(cmd)
  subprocess.check_call(' '.join(cmd), shell=True)

def CreateAgentSnapshot(bundle_dir, build_dir):
  platforms = join(bundle_dir, 'platforms')
  data_dir = join(platforms, 'raspberry-pi2', 'data')
  dart = join(build_dir, 'dart')
  snapshot = join(data_dir, 'dartino-agent.snapshot')
  CreateSnapshot(dart, 'pkg/dartino_agent/bin/agent.dart', snapshot)

def CopyArmDebPackage(bundle_dir, package):
  target = join(bundle_dir, 'platforms', 'raspberry-pi2')
  CopyFile(package, join(target, basename(package)))

def CopyAdditionalFiles(bundle_dir):
  for extra in ['README.md', 'LICENSE.md']:
    CopyFile(extra, join(bundle_dir, extra))

def CopyArm(bundle_dir):
  binaries = ['dartino-vm', 'natives.json']
  raspberry = join(bundle_dir, 'platforms', 'raspberry-pi2')
  bin_dir = join(raspberry, 'bin')
  makedirs(bin_dir)
  build_dir = 'out/ReleaseXARM'
  for v in binaries:
    CopyFile(join(build_dir, v), join(bin_dir, v))

def CopySTM(bundle_dir):
  libraries = [
      'libdartino.a',
      'libfreertos_dartino.a',
      'libstm32f746g-discovery.a',
      'libmbedtls.a',
    ]
  disco = join(bundle_dir, 'platforms', 'stm32f746g-discovery')
  lib_dir = join(disco, 'lib')
  makedirs(lib_dir)
  build_dir = 'out/ReleaseSTM'
  for lib in libraries:
    CopyFile(join(build_dir, lib), join(lib_dir, basename(lib)))

def CopyCM4(bundle_dir):
  libraries = [
      'libdartino.a',
      'libfreertos_dartino.a',
      'libstm32f411xe-nucleo.a',
    ]
  disco = join(bundle_dir, 'platforms', 'stm32f411re-nucleo')
  lib_dir = join(disco, 'lib')
  makedirs(lib_dir)
  build_dir = 'out/ReleaseCM4'
  for lib in libraries:
    CopyFile(join(build_dir, lib), join(lib_dir, basename(lib)))

def CopySamples(bundle_dir):
  target = join(bundle_dir, 'samples')
  for v in SAMPLES:
    copytree(join('samples', v), join(target, v))
  CopyFile(join('samples', 'dartino.yaml'), join(target, 'dartino.yaml'))

def CreateDocumentation():
  # Ensure all the dependencies of dartinodoc are available.
  exit_code = subprocess.call(
    [join('..', '..',ThirdPartyDartSdkDir(), 'bin', 'pub'), 'get'],
      cwd='pkg/dartinodoc')
  if exit_code != 0:
    raise OSError(exit_code)
  doc_dest = join('out', 'doc')
  EnsureDeleted(doc_dest)

  # Determine the sdk and third_party packages
  sdk_packages = Set()
  third_party_packages = Set()
  with open(join('pkg', 'dartino-sdk.packages')) as f:
    lines = f.read().splitlines()
  for line in lines:
    parts = line.split(':')
    name, path = parts
    if path.startswith('../third_party/'):
      third_party_packages.add(name)
    else:
      sdk_packages.add(name)

  exit_code = subprocess.call(
      [join(ThirdPartyDartSdkDir(), 'bin', 'dart'),
       '-c', 'pkg/dartinodoc/bin/dartinodoc.dart',
       '--output', doc_dest,
       '--sdk-packages', ",".join(sdk_packages),
       '--third-party-packages', ",".join(third_party_packages),
       '--version', utils.GetSemanticSDKVersion()])
  if exit_code != 0:
    raise OSError(exit_code)

def CopyTools(bundle_dir):
  tools_dir = join(bundle_dir, 'tools')
  makedirs(tools_dir)
  tools = ['gcc-arm-embedded', 'openocd']
  for tool in tools:
    tool_dir = join(tools_dir, tool)
    copytree('third_party/%s/linux/%s' % (tool, tool), tool_dir)

def Main():
  options = ParseOptions()
  build_dir = options.build_dir
  if not build_dir:
    print 'Please specify a build directory with "--build_dir".'
    sys.exit(1)
  sdk_dir = join(build_dir, 'dartino-sdk')
  print 'Creating sdk bundle for %s in %s' % (build_dir, sdk_dir)
  deb_package = options.deb_package
  with utils.TempDir() as sdk_temp:
    if options.create_documentation:
      CreateDocumentation()
    CopyBinaries(sdk_temp, build_dir)
    CopyDartSdk(sdk_temp)
    CopyInternalPackages(sdk_temp, build_dir)
    CopyLibs(sdk_temp, build_dir)
    CopyInclude(sdk_temp)
    CopyPackagesAndSettingsTemplate(sdk_temp)
    CopyPlatforms(sdk_temp)
    CopyArm(sdk_temp)
    CreateAgentSnapshot(sdk_temp, build_dir)
    CopySTM(sdk_temp)
    CopyCM4(sdk_temp)
    CopySamples(sdk_temp)
    CopyAdditionalFiles(sdk_temp)
    if deb_package:
      CopyArmDebPackage(sdk_temp, deb_package)
    EnsureDeleted(sdk_dir)
    if options.include_tools:
      CopyTools(sdk_temp)
    copytree(sdk_temp, sdk_dir)
  print 'Created sdk bundle for %s in %s' % (build_dir, sdk_dir)

if __name__ == '__main__':
  sys.exit(Main())
