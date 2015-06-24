#!/usr/bin/env python
# Copyright (c) 2012 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Windows can't run .sh files, so this is a Python implementation of
update.sh. This script should replace update.sh on all platforms eventually."""

import argparse
import contextlib
import cStringIO
import glob
import os
import pipes
import re
import shutil
import subprocess
import stat
import sys
import tarfile
import time
import urllib2
import zipfile

from os.path import dirname, join

# Path constants. (All of these should be absolute paths.)
THIS_DIR = os.path.abspath(os.path.dirname(__file__))
FLETCH_ROOT_DIR = os.path.abspath(os.path.join(THIS_DIR, '..'))
THIRD_PARTY_DIR = os.path.join(FLETCH_ROOT_DIR, 'third_party')

def GetClangDir(system):
  return os.path.join(THIRD_PARTY_DIR, 'clang', system)

def GetStampFile(system):
  return os.path.join(THIRD_PARTY_DIR, 'clang', '%s.stamp' % system)

# URL for pre-built binaries.
CDS_URL = 'https://commondatastorage.googleapis.com/chromium-browser-clang'


def DownloadUrl(url, output_file):
  """Download url into output_file."""
  CHUNK_SIZE = 4096
  TOTAL_DOTS = 10
  sys.stdout.write('Downloading %s ' % url)
  sys.stdout.flush()
  response = urllib2.urlopen(url)
  total_size = int(response.info().getheader('Content-Length').strip())
  bytes_done = 0
  dots_printed = 0
  while True:
    chunk = response.read(CHUNK_SIZE)
    if not chunk:
      break
    output_file.write(chunk)
    bytes_done += len(chunk)
    num_dots = TOTAL_DOTS * bytes_done / total_size
    sys.stdout.write('.' * (num_dots - dots_printed))
    sys.stdout.flush()
    dots_printed = num_dots
  print ' Done.'


def ReadStampFile(filename):
  """Return the contents of the stamp file, or '' if it doesn't exist."""
  try:
    with open(filename, 'r') as f:
      return f.read()
  except IOError:
    return ''


def WriteStampFile(filename, s):
  """Write s to the stamp file."""
  if not os.path.exists(os.path.dirname(filename)):
    os.makedirs(os.path.dirname(filename))
  with open(filename, 'w') as f:
    f.write(s)


def UpdateClang(args):
  # The URLs where we download the archived clang builds have the following
  # pattern:
  #    gs://chromium-browser-clang/Linux_x64/clang-<rev>*-1.tgz
  #    gs://chromium-browser-clang/Mac/clang-<rev>-1.tgz

  # This is incremented when pushing a new build of Clang at the same revision.
  package_version = "%s-%s" % (args.revision, args.sub_revision)

  if args.print_revision:
    print package_version
    return 0

  # clang packages are smaller than 50 MB, small enough to keep in memory.
  for system, directory in [('linux', 'Linux_x64'), ('mac', 'Mac')]:
    stamp_filename = GetStampFile(system)
    clang_dir = GetClangDir(system)

    print '[%s] Updating Clang to %s ...' % (system, package_version)
    if ReadStampFile(stamp_filename) == package_version:
      print 'Already up to date.'
      continue

    # Reset the stamp file in case the build is unsuccessful.
    WriteStampFile(stamp_filename, '')

    cds_full_url = '%s/%s/clang-%s.tgz' % (CDS_URL, directory, package_version)

    print '[%s] Trying to download prebuilt clang' % system
    with contextlib.closing(cStringIO.StringIO()) as f:
      if os.path.exists(clang_dir):
        print '[%s] Removing old clang dir %s ...' % (system, clang_dir)
        shutil.rmtree(clang_dir)

      DownloadUrl(cds_full_url, f)
      f.seek(0)
      tarfile.open(mode='r:gz', fileobj=f).extractall(path=clang_dir)

      print '[%s] clang %s unpacked' % (system, package_version)

      WriteStampFile(stamp_filename, package_version)
  return 0


def main():
  parser = argparse.ArgumentParser(description='Build Clang.')
  parser.add_argument('--print-revision', action='store_true',
                      help='print current clang revision and exit.')
  parser.add_argument('--revision', type=int, default=228129,
                      help='the revision of the archive to use.')
  parser.add_argument('--sub-revision', type=int, default=1,
                      help='the sub-revision of the archive to use.')

  args = parser.parse_args()

  # Don't buffer stdout, so that print statements are immediately flushed.
  # Do this only after --print-revision has been handled, else we'll get
  # an error message when this script is run from gn for some reason.
  sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)

  return UpdateClang(args)


if __name__ == '__main__':
  sys.exit(main())
