#!/usr/bin/env python
#
# Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.
#

import os
import optparse
import subprocess
import sys
import utils

import bots.dartino_namer as gcs_namer
import bots.bot_utils as bot_utils

def ParseOptions():
  parser = optparse.OptionParser()
  parser.add_option('--version')
  parser.add_option('--dryrun', action='store_true')
  (options, args) = parser.parse_args()
  return options

def Main():
  options = ParseOptions()
  version = options.version
  dryrun = options.dryrun
  gsutil = bot_utils.GSUtil()

  def gsutil_cp(src, target, recursive=False, public=True):
    cmd = ['-m', 'cp']
    if recursive:
      cmd.append('-r')
    if public:
      cmd.extend(['-a', 'public-read'])
    cmd.extend([src, target])
    if dryrun:
      print 'DRY: gsutil %s' % ' '.join(cmd)
    else:
      gsutil.execute(cmd)

  def gsutil_rm(target):
    if dryrun:
      print 'DRY: gsutil rm %s' % target
    else:
      gsutil.remove(target)

  def Run(cmd, shell=False):
    print "Running: %s" % ' '.join(cmd)
    if dryrun:
      print 'DRY: %s' % ' '.join(cmd)
    else:
      if shell:
        subprocess.check_call(' '.join(cmd), shell=shell)
      else:
        subprocess.check_call(cmd, shell=shell)

  # Currently we only release on dev
  raw_namer = gcs_namer.DartinoGCSNamer(channel=bot_utils.Channel.DEV)
  release_namer = gcs_namer.DartinoGCSNamer(
      channel=bot_utils.Channel.DEV,
      release_type=bot_utils.ReleaseType.RELEASE)
  delete_from_latest = gsutil.ls(
      release_namer.dartino_sdk_directory('latest')).split('\n')
  for target_version in [version, 'latest']:
    for system in ['linux', 'mac']:
      for arch in ['x64']:
        target = release_namer.dartino_sdk_zipfilepath(target_version, system,
                                                       arch, 'release')
        src = raw_namer.dartino_sdk_zipfilepath(version, system,
                                                arch, 'release')
        gsutil_cp(src, target)
        if target_version == 'latest' and target in delete_from_latest:
          delete_from_latest.remove(target)

  with utils.TempDir('version') as temp_dir:
    version_file = os.path.join(temp_dir, 'version')
    target = release_namer.version_filepath('latest')
    with open(version_file, 'w') as f:
      f.write(version)
    gsutil_cp(version_file, target)
    if target in delete_from_latest:
      delete_from_latest.remove(target)

  for name in delete_from_latest:
    if name:
      print
      print "-----WARNING - Deleting %s which is no longer used -----" % name
      print "-----If this file us used please fix your the script ---"
      print
      gsutil_rm(name)

  with utils.TempDir('docs') as temp_dir:
    docs = raw_namer.docs_filepath(version)
    print 'Downloading docs from %s' % docs
    gsutil_cp(docs, temp_dir, recursive=True, public=False)
    local_docs = os.path.join(temp_dir, 'docs')
    with utils.ChangedWorkingDirectory(temp_dir):
      print 'Cloning the dartino-api repo'
      Run(['git', 'clone', 'git@github.com:dartino/api.git'])
      apidir = '.' if dryrun else os.path.join(temp_dir, 'api')
      with utils.ChangedWorkingDirectory(apidir):
        print 'Checking out gh-pages which serves our documentation'
        Run(['git', 'checkout', 'gh-pages'])
        print 'Cleaning out old version of docs locally'
        Run(['git', 'rm', '-r', '*'])
        # shell=True to allow us to expand the *.
        print 'Copying in new docs'
        Run(['cp', '-r', os.path.join(local_docs, '*'), '.'], shell=True)
        print 'Git adding all new docs'
        Run(['git', 'add', '*'])
        print 'Commiting docs locally'
        Run(['git', 'commit', '-m',
             'Publish API docs for version %s' % version])
        print 'Pushing docs to github'
        Run(['git', 'push'])

if __name__ == '__main__':
  sys.exit(Main())
