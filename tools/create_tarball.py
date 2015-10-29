#!/usr/bin/env python
#
# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.
#

# Script to build a tarball of the Fletch source.
#
# The tarball includes all the source needed to build Fletch. This
# includes the fletch repository checkout, the source in third_party
# and the Dart repository checkout. As part of creating the tarball
# the files used to build Debian packages are copied to a top-level
# debian directory. This makes it easy to build Debian packages from
# the tarball.
#
# For building a Debian package one need to the tarball to follow the
# Debian naming rules upstream tar files.
#
#  $ mv fletch-XXX.tar.gz fletch_XXX.orig.tar.gz
#  $ tar xf fletch_XXX.orig.tar.gz
#  $ cd fletch_XXX
#  $ debuild -us -uc

import datetime
import optparse
import sys
import tarfile
from os import listdir
from os.path import join, split, abspath

import utils


HOST_OS = utils.GuessOS()
FLETCH_DIR = abspath(join(__file__, '..', '..'))
# The repository directory where fletch, dart and third_party are located.
REPO_DIR = abspath(join(__file__, '..', '..', '..'))
# Flags.
verbose = False

# Name of the fletch directory when unpacking the tarball.
versiondir = ''

# Ignore Git/SVN files, checked-in binaries, backup files, etc.
#
# Remember *not* to ignore scripts (currently in tools) that are used
# for building the modified Raspbian SD-card image as this tarball is
# added to that image to have it include all source required to
# generate it in the first place.
ignoredPaths = ['fletch/out',
                'fletch/tools/testing/bin',
                'fletch/third_party/clang',
                'fletch/third_party/bin/linux/qemu',
                'fletch/third_party/bin/linux/qemu.tar.gz',
                'fletch/third_party/lk',
                'fletch/third_party/openocd',
                'fletch/third_party/qemu',
                'fletch/version.gyp']
ignoredDirs = ['.svn', '.git']
ignoredEndings = ['.mk', '.pyc', 'Makefile', '~']

def BuildOptions():
  result = optparse.OptionParser()
  result.add_option("-v", "--verbose",
      help='Verbose output.',
      default=False, action="store_true")
  result.add_option("--tar_filename",
                    default=None,
                    help="The output file.")

  return result

def Filter(tar_info):
  # Get the name of the file relative to the REPO_DIR directory. Note the
  # name from the TarInfo does not include a leading slash.
  assert tar_info.name.startswith(REPO_DIR[1:])
  original_name = tar_info.name[len(REPO_DIR):]
  _, tail = split(original_name)
  if tail in ignoredDirs:
    return None
  for path in ignoredPaths:
    if original_name.startswith(path):
      return None
  for ending in ignoredEndings:
    if original_name.endswith(ending):
      return None
  # Add the fletch directory name with version. Place the debian
  # directory one level over the rest which are placed in the
  # directory 'fletch'. This enables building the Debian packages
  # out-of-the-box.
  tar_info.name = join(versiondir, original_name)
  if verbose:
    print 'Adding %s as %s' % (original_name, tar_info.name)
  return tar_info

def GenerateCopyright(filename):
  with open(join(FLETCH_DIR, 'LICENSE.md')) as lf:
    license_lines = lf.readlines()

  with open(filename, 'w') as f:
    f.write('Name: fletch\n')
    f.write('Maintainer: Dart Team <misc@dartlang.org>\n')
    f.write('Source: https://github.com/dart-lang/fletch/\n')
    f.write('License:\n')
    for line in license_lines:
      f.write(' %s' % line)  # Line already contains trailing \n.

def GenerateChangeLog(filename, version):
  with open(filename, 'w') as f:
    f.write('fletch (%s-1) UNRELEASED; urgency=low\n' % version)
    f.write('\n')
    f.write('  * Generated file.\n')
    f.write('\n')
    f.write(' -- Dart Team <misc@dartlang.org>  %s\n' %
            datetime.datetime.utcnow().strftime('%a, %d %b %Y %X +0000'))

def GenerateGitRevision(filename, git_revision):
  with open(filename, 'w') as f:
    f.write(str(git_revision))


def CreateTarball(tarfilename):
  global ignoredPaths  # Used for adding the output directory.
  # Generate the name of the tarfile
  version = utils.GetVersion()
  global versiondir
  versiondir = 'fletch-%s' % version
  debian_dir = 'tools/linux_dist_support/debian'
  # Don't include the build directory in the tarball (ignored paths
  # are relative to FLETCH_DIR).
  builddir = utils.GetBuildDir(HOST_OS)
  ignoredPaths.append(builddir)

  print 'Creating tarball: %s' % tarfilename
  with tarfile.open(tarfilename, mode='w:gz') as tar:
    for f in listdir(FLETCH_DIR):
      tar.add(join(FLETCH_DIR, f), filter=Filter)
    for f in listdir(join(FLETCH_DIR, debian_dir)):
      tar.add(join(FLETCH_DIR, debian_dir, f),
              arcname='%s/debian/%s' % (versiondir, f))
    tar.add(join(FLETCH_DIR, 'platforms/raspberry-pi2/data/fletch-agent'),
            arcname='%s/debian/fletch-agent.init' % versiondir)
    tar.add(join(FLETCH_DIR, 'platforms/raspberry-pi2/data/fletch-agent.env'),
            arcname='%s/debian/fletch-agent.default' % versiondir)

    with utils.TempDir() as temp_dir:
      # Generate and add debian/copyright
      copyright_file = join(temp_dir, 'copyright')
      GenerateCopyright(copyright_file)
      tar.add(copyright_file, arcname='%s/debian/copyright' % versiondir)

      # Generate and add debian/changelog
      change_log = join(temp_dir, 'changelog')
      GenerateChangeLog(change_log, version)
      tar.add(change_log, arcname='%s/debian/changelog' % versiondir)

      # Add the GIT_REVISION file.
      git_revision = join(temp_dir, 'GIT_REVISION')
      GenerateGitRevision(git_revision, utils.GetGitRevision())
      tar.add(git_revision,
              arcname='%s/fletch/tools/GIT_REVISION' % versiondir)

def Main():
  if HOST_OS != 'linux':
    print 'Tarball can only be created on linux'
    return -1

  # Parse the options.
  parser = BuildOptions()
  (options, args) = parser.parse_args()
  if options.verbose:
    global verbose
    verbose = True

  tar_filename = options.tar_filename
  if not tar_filename:
    tar_filename = join(FLETCH_DIR,
                        utils.GetBuildDir(HOST_OS),
                        'fletch-%s.tar.gz' % utils.GetVersion())

  CreateTarball(tar_filename)

if __name__ == '__main__':
  sys.exit(Main())
