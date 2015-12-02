#!/usr/bin/env python
# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# This script is creating a self contained directory with all the tools,
# libraries, packages and samples needed for running fletch.

# This script assumes that the target arg has been build in the passed in
# --build_dir. It also assumes that out/ReleaseXARM/fletch-vm has been build.

import optparse
import subprocess
import sys
import utils
import re

from sets import Set
from os import makedirs
from os.path import dirname, join, exists, basename, abspath
from shutil import copyfile, copymode, copytree, rmtree

TOOLS_DIR = abspath(dirname(__file__))

SDK_PACKAGES = ['ffi', 'file', 'fletch', 'gpio', 'http', 'i2c', 'os',
                'raspberry_pi', 'socket']
THIRD_PARTY_PACKAGES = ['charcode']

SAMPLES = ['raspberry-pi2', 'general']
with open(join(TOOLS_DIR, 'docs_html', 'head.html')) as f:
  DOC_INDEX_HEAD = f.read()
with open(join(TOOLS_DIR, 'docs_html', 'tail.html')) as f:
  DOC_INDEX_TAIL = f.read()

DOC_ENTRY = ('<dt><span class="name"><a class="" href="%s/index.html">%s</a>'
             '</span></dt>')

DOC_INDEX = '%s%s%s' % (
    DOC_INDEX_HEAD,
    '\n'.join([DOC_ENTRY % (p, p) for p in SDK_PACKAGES]),
    DOC_INDEX_TAIL)

def ParseOptions():
  parser = optparse.OptionParser()
  parser.add_option("--build_dir")
  parser.add_option("--deb_package")
  parser.add_option("--create_documentation", default=False,
                    action="store_true")
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

def CopyBinaries(bundle_dir, build_dir):
  bin_dir = join(bundle_dir, 'bin')
  internal = join(bundle_dir, 'internal')
  makedirs(bin_dir)
  makedirs(internal)
  CopyFile(join(build_dir, 'fletch-vm'), join(bin_dir, 'fletch-vm'))
  # The driver for the sdk is specially named fletch_for_sdk.
  CopyFile(join(build_dir, 'fletch_for_sdk'), join(bin_dir, 'fletch'))
  # We move the dart vm to internal to not put it on the path of users
  CopyFile(join(build_dir, 'dart'), join(internal, 'dart'))
  # natives.json is read relative to the dart binary
  CopyFile(join(build_dir, 'natives.json'), join(internal, 'natives.json'))

# We have two lib dependencies: the libs from the sdk and the libs dir with
# patch files from the fletch repo.
def CopyLibs(bundle_dir, build_dir):
  internal = join(bundle_dir, 'internal')
  fletch_lib = join(internal, 'fletch_lib')
  dart_lib = join(internal, 'dart_lib')
  copytree('lib', join(fletch_lib, 'lib'))
  copytree('third_party/dart/sdk/lib', join(dart_lib, 'lib'))

def CopyInternalPackages(bundle_dir, build_dir):
  internal_pkg = join(bundle_dir, 'internal', 'pkg')
  makedirs(internal_pkg)
  # Copy the pkg dirs for tools and the pkg dirs referred from their
  # .packages files.
  copied_pkgs = Set()
  for tool in ['fletchc', 'flash_sd_card']:
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

def CopyPackages(bundle_dir):
  target_dir = join(bundle_dir, 'pkg')
  makedirs(target_dir)
  with open(join(bundle_dir, 'internal', 'fletch-sdk.packages'), 'w') as p:
    for package in SDK_PACKAGES:
      copytree(join('pkg', package), join(target_dir, package))
      p.write('%s:../pkg/%s/lib\n' % (package, package))
    for package in THIRD_PARTY_PACKAGES:
      copytree(join('third_party', package), join(target_dir, package))
      p.write('%s:../pkg/%s/lib\n' % (package, package))

def CopyPlatforms(bundle_dir):
  target_dir = join(bundle_dir, 'platforms')
  copytree('platforms', target_dir)

def CreateSnapshot(dart_executable, dart_file, snapshot):
  cmd = [dart_executable, '-c', '--packages=.packages',
         '-Dsnapshot="%s"' % snapshot,
         '-Dpackages=".packages"',
         'tests/fletchc/run.dart', dart_file]
  print 'Running %s' % ' '.join(cmd)
  subprocess.check_call(' '.join(cmd), shell=True)

def CreateAgentSnapshot(bundle_dir, build_dir):
  platforms = join(bundle_dir, 'platforms')
  data_dir = join(platforms, 'raspberry-pi2', 'data')
  dart = join(build_dir, 'dart')
  snapshot = join(data_dir, 'fletch-agent.snapshot')
  CreateSnapshot(dart, 'pkg/fletch_agent/bin/agent.dart', snapshot)

def CopyArmDebPackage(bundle_dir, package):
  target = join(bundle_dir, 'platforms', 'raspberry-pi2')
  CopyFile(package, join(target, basename(package)))

def CopyAdditionalFiles(bundle_dir):
  for extra in ['README.md', 'LICENSE.md']:
    CopyFile(extra, join(bundle_dir, extra))

def CopyArm(bundle_dir):
  binaries = ['fletch-vm', 'natives.json']
  raspberry = join(bundle_dir, 'platforms', 'raspberry-pi2')
  bin_dir = join(raspberry, 'bin')
  makedirs(bin_dir)
  build_dir = 'out/ReleaseXARM'
  for v in binaries:
    CopyFile(join(build_dir, v), join(bin_dir, v))

def CopySamples(bundle_dir):
  target = join(bundle_dir, 'samples')
  for v in SAMPLES:
    copytree(join('samples', v), join(target, v))

def EnsureDartDoc():
  subprocess.check_call(
      'download_from_google_storage -b dart-dependencies-fletch '
      '-u -d third_party/dartdoc_deps/',
      shell=True)

def CreateDocsPubSpec(fileName):
  print 'Doc-gen: creating %s' %fileName
  f = open(fileName, 'w')
  f.write('name: Fletch_SDK\n')
  f.write('dependencies:\n')
  for package in SDK_PACKAGES:
    f.write('  %s:\n' % package)
    f.write('    path: ../%s\n' % package)
  f.close()

def CreateDocsLibs(docPkgDir, outDir):
  for package in SDK_PACKAGES:
    # Read the original package file and match out the documentation from it.
    sourceFileName = join(outDir, package, 'lib', '{0}.dart'.format(package))
    with open(sourceFileName) as f:
      s = f.read()
    # Extract the doc comment for the library; this is everything before a line
    # that starts with 'library' and ends with ';'.
    match = re.match(r'(.*)^library ([^;]+);', s, re.DOTALL|re.MULTILINE)
    doc = match.group(1)
    # Create a new lib dart file with same documentation.
    destFileName = join(docPkgDir, '%s.dart' % package)
    print 'Doc-gen: Creating %s from %s' % (destFileName, sourceFileName)
    with open(destFileName, 'w') as f:
      f.write(match.group(1))
      f.write('\nlibrary {0};\n'.format(package))
      f.write('export \'package:{0}/{0}.dart\';'.format(package))

def CreateDocumentation():
  EnsureDartDoc()
  docs_out = join('out', 'docs')
  sdk = join('third_party', 'dartdoc_deps', 'dart-sdk')
  sdk_dst = join('out', 'dartdoc-dart-sdk')
  EnsureDeleted(sdk_dst)
  copytree(sdk, sdk_dst)
  copytree('lib', join(sdk_dst, 'lib', 'mobile'))
  pub = abspath(join(sdk_dst, 'bin', 'pub'))
  dartdoc = join(sdk_dst, 'bin', 'dartdoc')
  # We recreate the same structure we have in the repo in a copy to not
  # polute our workspace
  with utils.TempDir() as temp:
    # Copy Fletch packages.
    pkg_copy = join(temp, 'pkg')
    makedirs(pkg_copy)
    for pkg in SDK_PACKAGES:
      pkg_path = join('pkg', pkg)
      pkg_dst = join(pkg_copy, pkg)
      copytree(pkg_path, pkg_dst)
      print 'copied %s to %s' % (pkg_path, pkg_dst)
    # Copy third party packages.
    third_party_copy = join(temp, 'third_party')
    makedirs(third_party_copy)
    for pkg in THIRD_PARTY_PACKAGES:
      pkg_path = join('third_party', pkg)
      pkg_dst = join(third_party_copy, pkg)
      copytree(pkg_path, pkg_dst)
      print 'copied %s to %s' % (pkg_path, pkg_dst)
    # Create fake combined package dir.
    sdk_pkg_dir = join(pkg_copy, 'fletch_sdk')
    makedirs(sdk_pkg_dir)
    # Copy readme.
    copyfile(join('pkg', 'fletch_sdk_readme.md'),
             join(sdk_pkg_dir, 'README.md'))
    # Add pubspec file.
    CreateDocsPubSpec('%s/pubspec.yaml' % sdk_pkg_dir)
    # Add lib dir, and a generated file for each package.
    sdk_pkg_lib_dir = join(sdk_pkg_dir, 'lib')
    makedirs(sdk_pkg_lib_dir)
    CreateDocsLibs(sdk_pkg_lib_dir, pkg_copy)
    # Call pub get.
    with utils.ChangedWorkingDirectory(sdk_pkg_dir):
      subprocess.check_call([pub, 'get'])
      print 'Called pub get in %s' % pkg_dst
    # Call dartdoc.
    EnsureDeleted(docs_out)
    subprocess.check_call([dartdoc, '--input', sdk_pkg_dir,'--output',
                          docs_out])

    # Patch the generated index.html file to fix a few issues.
    indexFile = join(docs_out, 'index.html')
    with open(indexFile, 'r') as fin:
      s = fin.read()
      s = s.replace('Fletch_SDK', 'Fletch SDK')
      s = s.replace('>package<', '><')
    with open(indexFile, 'w') as fout:
      fout.write(s)


def Main():
  options = ParseOptions();
  print 'Creating sdk bundle for %s' % options.build_dir
  build_dir = options.build_dir
  deb_package = options.deb_package
  with utils.TempDir() as sdk_temp:
    if options.create_documentation:
      CreateDocumentation()
    CopyBinaries(sdk_temp, build_dir)
    CopyInternalPackages(sdk_temp, build_dir)
    CopyLibs(sdk_temp, build_dir)
    CopyPackages(sdk_temp)
    CopyPlatforms(sdk_temp)
    CopyArm(sdk_temp)
    CreateAgentSnapshot(sdk_temp, build_dir)
    CopySamples(sdk_temp)
    CopyAdditionalFiles(sdk_temp)
    if deb_package:
      CopyArmDebPackage(sdk_temp, deb_package)
    sdk_dir = join(build_dir, 'fletch-sdk')
    EnsureDeleted(sdk_dir)
    copytree(sdk_temp, sdk_dir)

if __name__ == '__main__':
  sys.exit(Main())
