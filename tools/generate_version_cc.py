#!/usr/bin/env python
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

import os
import sys
import platform
import re
import subprocess

version_cc_template = """\
// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/version.h"

namespace dartino {

extern "C"
const char* GetVersion() {
  return "%(version)s";
}

}  // namespace dartino
""";

# Most of what is below (all except Main)  has been copied from
# ../third_party/dart/tools/utils.py. This is normally through importing utils
# (import utils) which will forward to ../third_party/dart/tools/utils.py
# (see utils/__init__.py). However to get a hermetic build for building the
# Dartino VM as an LK module we need this here to avoid having to run
# gclient sync.
BASE_DIR = os.path.abspath(os.path.join(os.curdir, '..'))
DART_DIR = os.path.abspath(os.path.join(__file__, '..', '..'))
VERSION_FILE = os.path.join(DART_DIR, 'tools', 'VERSION')

class Version(object):
  def __init__(self, channel, major, minor, patch, prerelease,
               prerelease_patch):
    self.channel = channel
    self.major = major
    self.minor = minor
    self.patch = patch
    self.prerelease = prerelease
    self.prerelease_patch = prerelease_patch

# Try to guess the host operating system.
def GuessOS():
  os_id = platform.system()
  if os_id == "Linux":
    return "linux"
  elif os_id == "Darwin":
    return "macos"
  elif os_id == "Windows" or os_id == "Microsoft":
    # On Windows Vista platform.system() can return "Microsoft" with some
    # versions of Python, see http://bugs.python.org/issue1082 for details.
    return "win32"
  elif os_id == 'FreeBSD':
    return 'freebsd'
  elif os_id == 'OpenBSD':
    return 'openbsd'
  elif os_id == 'SunOS':
    return 'solaris'
  else:
    return None

# Returns true if we're running under Windows.
def IsWindows():
  return GuessOS() == 'win32'

def GetSemanticSDKVersion(ignore_svn_revision=False):
  version = ReadVersionFile()
  if not version:
    return None

  if version.channel == 'be':
    postfix = '-edge' if ignore_svn_revision else '-edge.%s' % GetGitRevision()
  elif version.channel == 'dev':
    postfix = '-dev.%s.%s' % (version.prerelease, version.prerelease_patch)
  else:
    assert version.channel == 'stable'
    postfix = ''

  return '%s.%s.%s%s' % (version.major, version.minor, version.patch, postfix)

def ReadVersionFile():
  def match_against(pattern, file_content):
    match = re.search(pattern, file_content, flags=re.MULTILINE)
    if match:
      return match.group(1)
    return None

  try:
    fd = open(VERSION_FILE)
    content = fd.read()
    fd.close()
  except:
    print "Warning: Couldn't read VERSION file (%s)" % VERSION_FILE
    return None

  channel = match_against('^CHANNEL ([A-Za-z0-9]+)$', content)
  major = match_against('^MAJOR (\d+)$', content)
  minor = match_against('^MINOR (\d+)$', content)
  patch = match_against('^PATCH (\d+)$', content)
  prerelease = match_against('^PRERELEASE (\d+)$', content)
  prerelease_patch = match_against('^PRERELEASE_PATCH (\d+)$', content)

  if channel and major and minor and prerelease and prerelease_patch:
    return Version(
        channel, major, minor, patch, prerelease, prerelease_patch)
  else:
    print "Warning: VERSION file (%s) has wrong format" % VERSION_FILE
    return None

def GetGitRevision():
  # When building from tarball use tools/GIT_REVISION
  git_revision_file = os.path.join(DART_DIR, 'tools', 'GIT_REVISION')
  try:
    with open(git_revision_file) as fd:
      return fd.read()
  except:
    pass

  p = subprocess.Popen(['git', 'log', '-n', '1', '--pretty=format:%H'],
                       stdout = subprocess.PIPE,
                       stderr = subprocess.STDOUT, shell=IsWindows(),
                       cwd = DART_DIR)
  output, _ = p.communicate()
  # We expect a full git hash
  if len(output) != 40:
    print "Warning: could not parse git commit, output was %s" % output
    return None
  return output

def Main():
  args = sys.argv[1:]
  version_cc = args[2]
  version = GetSemanticSDKVersion()
  updated_content = version_cc_template % {"version": version}
  with open(version_cc, 'w') as f:
    f.write(updated_content)
  return 0


if __name__ == '__main__':
  sys.exit(Main())
