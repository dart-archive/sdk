#!/usr/bin/python

# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

"""
Buildbot steps for building Dart SDK with Fletch-specific patches.
"""
import os
import sys
# We run this as third_party/fletch/tools/bots/sdk_fletch_patched.py
sys.path.insert(0, os.path.join('tools', 'bots'))

import bot
import bot_utils
import re

utils = bot_utils.GetUtils()

PATCHED_BUILDER = r'dart-sdk-fletch-patched-(linux|mac)-(x64|arm)'

def BuildConfig(name, is_buildbot):
  """Returns info for the current buildbot."""
  pattern = re.match(PATCHED_BUILDER, name)
  if pattern:
    system = pattern.group(1)
    arch = pattern.group(2)
    if system == 'mac': system = 'macos'
    return bot.BuildInfo('none', 'none', 'release', system, arch=arch)
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
