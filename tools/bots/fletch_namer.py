# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import bot_utils

class FletchGCSNamer(bot_utils.GCSNamer):
  def __init__(self, channel=bot_utils.Channel.BLEEDING_EDGE,
               release_type=bot_utils.ReleaseType.RAW):
    super(FletchGCSNamer, self).__init__(channel, release_type, False)
    self.bucket = 'gs://fletch-archive'

  def fletch_sdk_directory(self, revision):
    return self._variant_directory('sdk', revision)

  def fletch_sdk_zipfilename(self, system, arch, mode):
    assert mode in bot_utils.Mode.ALL_MODES
    return 'fletch-sdk-%s-%s-%s.zip' % (
        bot_utils.SYSTEM_RENAMES[system], bot_utils.ARCH_RENAMES[arch], mode)

  def fletch_sdk_zipfilepath(self, revision, system, arch, mode):
    return '/'.join([self.fletch_sdk_directory(revision),
        self.fletch_sdk_zipfilename(system, arch, mode)])

  def arm_binaries_zipfilename(self, mode):
    assert mode in bot_utils.Mode.ALL_MODES
    return 'arm-binaries-%s.zip' %  mode

  def arm_binaries_zipfilepath(self, revision, mode):
    return '/'.join([self.fletch_sdk_directory(revision),
        self.arm_binaries_zipfilename(mode)])
