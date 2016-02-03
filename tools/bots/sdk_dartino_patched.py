#!/usr/bin/python

# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

"""
Buildbot steps for building Dart SDK with Dartino-specific patches.
"""
import os
import sys
# We run this as third_party/dartino/tools/bots/sdk_dartino_patched.py
sys.path.insert(0, os.path.join('tools', 'bots'))

import bot
import bot_utils
import re

utils = bot_utils.GetUtils()

PATCHED_BUILDER = r'dart-sdk-dartino-patched-(linux|mac)-(x64|arm)'

def BuildConfig(name, is_buildbot):
  """Returns info for the current buildbot."""
  pattern = re.match(PATCHED_BUILDER, name)
  if pattern:
    system = pattern.group(1)
    arch = pattern.group(2)
    if system == 'mac': system = 'macos'
    return bot.BuildInfo('none', 'none', 'release', system, arch=arch)
  return None


def Archive(gcs_name, vm_path, link_name):
  download_link = 'https://storage.googleapis.com/%s' % gcs_name
  gcs_path = 'gs://%s' % gcs_name
  gsutil = bot_utils.GSUtil()
  gsutil.upload(vm_path, gcs_path)
  print '@@@STEP_LINK@download %s@%s@@@' % (link_name, download_link)
  sys.stdout.flush()
  

def BuildSteps(build_info):
  with bot.BuildStep('Upload VM to GCS'):
    # The build binary in the sdk is stripped, the one in build_root is not.
    # We archive the unstripped binaries in case we need to debug a vm crash.
    sdk_bin_path = utils.GetBuildSdkBin(build_info.system,
                                        build_info.mode,
                                        build_info.arch)
    build_root = utils.GetBuildRoot(build_info.system,
                                    build_info.mode,
                                    build_info.arch)
    revision = utils.GetGitRevision()
    archive_path = 'dartino-archive/patched_dart_sdks/%s/' % revision
    stripped_name = '%sdart-vm-%s-%s' % (archive_path, build_info.arch,
                                         build_info.system)
    unstripped_name = '%sdart-vm-%s-%s-symbols' % (archive_path,
                                                   build_info.arch,
                                                   build_info.system)

    unstripped_vm = os.path.join(build_root, 'dart')
    stripped_vm = os.path.join(sdk_bin_path, 'dart')
    Archive(stripped_name, stripped_vm, 'stripped')
    Archive(unstripped_name, unstripped_vm, 'unstripped')

if __name__ == '__main__':
  bot.RunBot(BuildConfig, BuildSteps)
