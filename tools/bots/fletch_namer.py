# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import bot_utils

class FletchGCSNamer(bot_utils.GCSNamer):
  def __init__(self, channel=bot_utils.Channel.BLEEDING_EDGE,
               release_type=bot_utils.ReleaseType.RAW, temporary=False):
    super(FletchGCSNamer, self).__init__(channel, release_type, False)
    if temporary:
      self.bucket = 'gs://fletch-temporary'
    else:
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

  def arm_agent_filename(self, revision):
    return 'fletch-agent_%s-1_armhf.deb' % revision

  def src_tar_name(self, revision):
    return 'fletch-%s.tar.gz' % revision

  def arm_agent_filepath(self, revision):
    return '/'.join([self.fletch_sdk_directory(revision),
        self.arm_agent_filename(revision)])

  def raspbian_filename(self):
    return 'fletch_raspbian.img'

  def raspbian_zipfilename(self):
    return '%s.zip' % self.raspbian_filename()

  def raspbian_zipfilepath(self, revision):
    return '/'.join([self.fletch_sdk_directory(revision),
        self.raspbian_zipfilename()])

  def version_filepath(self, revision):
    return '/'.join([self.fletch_sdk_directory(revision), 'VERSION'])

  def gcc_embedded_bundle_zipfilename(self, system):
    return 'gcc-arm-embedded-%s.zip' % system

  def gcc_embedded_bundle_filepath(self, revision, system):
    return '/'.join([self.fletch_sdk_directory(revision),
                     self.gcc_bundle_zipfilename(system)])

  def docs_filepath(self, revision):
    return '/'.join([self.fletch_sdk_directory(revision), 'docs'])
