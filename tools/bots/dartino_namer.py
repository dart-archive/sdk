# Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import bot_utils

class DartinoGCSNamer(bot_utils.GCSNamer):
  def __init__(self, channel=bot_utils.Channel.BLEEDING_EDGE,
               release_type=bot_utils.ReleaseType.RAW, temporary=False):
    super(DartinoGCSNamer, self).__init__(channel, release_type, False)
    if temporary:
      self.bucket = 'gs://dartino-temporary'
    else:
      self.bucket = 'gs://dartino-archive'

  def dartino_sdk_directory(self, revision):
    return self._variant_directory('sdk', revision)

  def dartino_sdk_zipfilename(self, system, arch, mode):
    assert mode in bot_utils.Mode.ALL_MODES
    return 'dartino-sdk-%s-%s-%s.zip' % (
        bot_utils.SYSTEM_RENAMES[system], bot_utils.ARCH_RENAMES[arch], mode)

  def dartino_sdk_zipfilepath(self, revision, system, arch, mode):
    return '/'.join([self.dartino_sdk_directory(revision),
        self.dartino_sdk_zipfilename(system, arch, mode)])

  def cross_binaries_zipfilename(self, mode, arch):
    assert mode in bot_utils.Mode.ALL_MODES
    return '%s-binaries-%s.zip' % (arch, mode)

  def cross_binaries_zipfilepath(self, revision, mode, arch):
    return '/'.join([self.dartino_sdk_directory(revision),
                     self.cross_binaries_zipfilename(mode, arch)])

  def arm_agent_filename(self, revision):
    return 'dartino-agent_%s-1_armhf.deb' % revision

  def src_tar_name(self, revision):
    return 'dartino-%s.tar.gz' % revision

  def arm_agent_filepath(self, revision):
    return '/'.join([self.dartino_sdk_directory(revision),
        self.arm_agent_filename(revision)])

  def raspbian_filename(self):
    return 'dartino_raspbian.img'

  def raspbian_zipfilename(self):
    return '%s.zip' % self.raspbian_filename()

  def raspbian_zipfilepath(self, revision):
    return '/'.join([self.dartino_sdk_directory(revision),
        self.raspbian_zipfilename()])

  def version_filepath(self, revision):
    return '/'.join([self.dartino_sdk_directory(revision), 'VERSION'])

  def gcc_embedded_bundle_zipfilename(self, system):
    return 'gcc-arm-embedded-%s.zip' % system

  def gcc_embedded_bundle_filepath(self, revision, system):
    return '/'.join([self.dartino_sdk_directory(revision),
                     self.gcc_embedded_bundle_zipfilename(system)])

  def openocd_bundle_zipfilename(self, system):
    return 'openocd-%s.zip' % system

  def openocd_bundle_filepath(self, revision, system):
    return '/'.join([self.dartino_sdk_directory(revision),
                     self.openocd_bundle_zipfilename(system)])

  def docs_filepath(self, revision):
    return '/'.join([self.dartino_sdk_directory(revision), 'docs'])
