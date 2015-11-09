#!/usr/bin/env python
#
# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.
#

import os
import optparse
import sys
import utils

import bots.fletch_namer as gcs_namer
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

  def gsutil_cp(src, target):
    cmd = ['cp', '-a', 'public-read', src, target]
    if dryrun:
      print 'DRY: gsutil %s' % ' '.join(cmd)
    else:
      gsutil.execute(cmd)

  # Currently we only release on dev
  raw_namer = gcs_namer.FletchGCSNamer(channel=bot_utils.Channel.DEV)
  release_namer = gcs_namer.FletchGCSNamer(
      channel=bot_utils.Channel.DEV,
      release_type=bot_utils.ReleaseType.RELEASE)
  for target_version in [version, 'latest']:
    for system in ['linux', 'mac']:
      for arch in ['x64']:
        src = raw_namer.fletch_sdk_zipfilepath(version, system, arch, 'release')
        target = release_namer.fletch_sdk_zipfilepath(target_version, system,
                                                      arch, 'release')
        gsutil_cp(src, target)

  with utils.TempDir('version') as temp_dir:
    version_file = os.path.join(temp_dir, 'version')
    target = release_namer.version_filepath('latest')
    with open(version_file, 'w') as f:
      f.write(version)
    gsutil_cp(version_file, target)

if __name__ == '__main__':
  sys.exit(Main())
