#!/usr/bin/env python
#
# Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.
#

# Script to build a Debian packages from a Dartino tarball.
#
# Right now this script only supports building the installation for a ARM Linux
# target running the Dartino agent
#
# The script will build a source package and a ARM binary packages.

import optparse
import os
import sys
import tarfile
import subprocess
import utils
from os.path import join, exists, abspath
from shutil import copyfile

HOST_OS = utils.GuessOS()
HOST_CPUS = utils.GuessCpus()
DARTINO_DIR = abspath(join(__file__, '..', '..'))

def BuildOptions():
  result = optparse.OptionParser()
  result.add_option("--tar_filename",
                    default=None,
                    help="The tar file to build from.")
  result.add_option("--out_dir",
                    default=None,
                    help="Where to put the packages.")
  result.add_option("-a", "--arch",
                    help='Target architectures (comma-separated).',
                    metavar='[all,armhf]',
                    default='armhf')
  result.add_option("-t", "--toolchain",
      help='Cross-compilation toolchain prefix',
      default=None)

  return result

def RunBuildPackage(opt, cwd, toolchain=None):
  env = os.environ.copy()
  if toolchain != None:
    env["TOOLCHAIN"] = '--toolchain=' + toolchain
  cmd = ['dpkg-buildpackage', '-j%d' % HOST_CPUS]
  cmd.extend(opt)
  process = subprocess.Popen(cmd,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             cwd=cwd, env=env)
  (stdout, stderr) = process.communicate()
  if process.returncode != 0:
    raise Exception('Command \'%s\' failed: %s\nSTDOUT: %s' %
                    (' '.join(cmd), stderr, stdout))

def BuildDebianPackage(tarball, out_dir, arch, toolchain):
  version = utils.GetVersion()
  tarroot = 'dartino-%s' % version
  origtarname = 'dartino_%s.orig.tar.gz' % version

  if not exists(tarball):
    print 'Source tarball not found'
    return -1

  with utils.TempDir() as temp_dir:
    origtarball = join(temp_dir, origtarname)
    copyfile(tarball, origtarball)

    with tarfile.open(origtarball) as tar:
      tar.extractall(path=temp_dir)

    # Build source package.
    print "Building source package"
    RunBuildPackage(['-S', '-us', '-uc'], join(temp_dir, tarroot))

    # Build the binary package for a ARM target on a x64 host.
    if 'armhf' in arch:
      print "Building package"
      RunBuildPackage(
          ['-B', '-aarmhf', '-us', '-uc'], join(temp_dir, tarroot), toolchain)

    # Copy the Debian package files to the build directory.
    debbase = 'dartino_%s' % version
    agent_debbase = 'dartino-agent_%s' % version
    source_package = [
      '%s-1.dsc' % debbase,
      '%s.orig.tar.gz' % debbase,
      '%s-1.debian.tar.gz' % debbase
    ]
    armhf_package = [
      '%s-1_armhf.deb' % agent_debbase
    ]

    for name in source_package:
      copyfile(join(temp_dir, name), join(out_dir, name))
    if ('armhf' in arch):
      for name in armhf_package:
        print "Writing package %s" % join(out_dir, name)
        copyfile(join(temp_dir, name), join(out_dir, name))

def Main():
  if HOST_OS != 'linux':
    print 'Debian build only supported on linux'
    return -1

  options, args = BuildOptions().parse_args()
  out_dir = options.out_dir
  tar_filename = options.tar_filename
  if options.arch == 'all':
    options.arch = 'armhf'
  arch = options.arch.split(',')

  if not options.out_dir:
    out_dir = join(DARTINO_DIR, 'out')

  if not tar_filename:
    tar_filename = join(DARTINO_DIR,
                        utils.GetBuildDir(HOST_OS),
                        'dartino-%s.tar.gz' % utils.GetVersion())

  BuildDebianPackage(tar_filename, out_dir, arch, options.toolchain)

if __name__ == '__main__':
  sys.exit(Main())
