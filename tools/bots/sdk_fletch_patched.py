#!/usr/bin/python

# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

"""
Buildbot steps for building Dart SDK with Fletch-specific patches.
"""
import bot
import bot_utils
import os
import re
import sys

utils = bot_utils.GetUtils()

PATCHED_X64_BUILDER = r'dart-sdk-fletch-patched-(linux|mac)-x64'
PATCHED_ARM_BUILDER = r'dart-sdk-fletch-patched-cross-linux-arm'


def BuildConfig(name, is_buildbot):
  """Returns info for the current buildbot."""
  x64_pattern = re.match(PATCHED_X64_BUILDER, name)
  if x64_pattern:
    system = x64_pattern.group(1)
    if system == 'mac': system = 'macos'
    return bot.BuildInfo('none', 'none', 'release', system, arch='x64')

  arm_pattern = re.match(PATCHED_ARM_BUILDER, name)
  if arm_pattern:
    return bot.BuildInfo('none', 'none', 'release', 'linux', arch='arm')

  return None


def BuildSteps(build_info):
  with bot.BuildStep('Upload VM to GCS'):
    sdk_bin_path = utils.GetBuildSdkBin(build_info.system,
                                        build_info.mode,
                                        build_info.arch)
    revision = utils.GetGitRevision()
    name = 'fletch-archive/%s/dart-vm-%s-%s' % (
        revision, build_info.arch, build_info.system)
    download_link = 'https://storage.googleapis.com/%s' % name
    gcs_path = 'gs://%s' % name
    vm_path = os.path.join(sdk_bin_path, 'dart')

    gsutil = bot_utils.GSUtil()
    gsutil.upload(vm_path, gcs_path)
    print '@@@STEP_LINK@download@%s@@@' % download_link
    sys.stdout.flush()


if __name__ == '__main__':
  bot.RunBot(BuildConfig, BuildSteps)
