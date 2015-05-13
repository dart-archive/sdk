#!/usr/bin/python

# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import os
import sys
import utils
import subprocess


def invoke_clang(args):
  fletch_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
  fletch_root = os.path.dirname(fletch_path)
  os_name = utils.GuessOS()
  if os_name == "macos":
    os_name = "mac"
    args.extend([
      '-isysroot',
      subprocess.check_output(['xcrun', '--show-sdk-path']).strip()])
  clang_bin = os.path.join(
    fletch_root, "third_party", "clang", os_name, "bin", "clang++")
  print clang_bin
  args.insert(0, clang_bin)
  print "'%s'" % "' '".join(args)
  os.execv(clang_bin, args)


def invoke_gcc(args):
  args.insert(0, "g++")
  os.execv("/usr/bin/g++", args)


def invoke_gcc_arm(args):
  args.insert(0, "arm-linux-gnueabihf-g++-4.8")
  os.execv("/usr/bin/arm-linux-gnueabihf-g++-4.8", args)


def invoke_gcc_arm64(args):
  args.insert(0, "aarch64-linux-gnu-g++-4.8")
  os.execv("/usr/bin/aarch64-linux-gnu-g++-4.8", args)


def main():
  args = sys.argv[1:]
  if "-L/FLETCH_ASAN" in args:
    args.remove("-L/FLETCH_ASAN")
    args.insert(0, '-fsanitize-undefined-trap-on-error')
    args.insert(0, '-fsanitize=address')
  if "-DFLETCH_CLANG" in args:
    args.remove("-DFLETCH_CLANG")
    invoke_clang(args)
  elif "-L/FLETCH_CLANG" in args:
    args.remove("-L/FLETCH_CLANG")
    invoke_clang(args)
  elif "-DFLETCH_ARM" in args:
    invoke_gcc_arm(args)
  elif "-L/FLETCH_ARM" in args:
    args.remove("-L/FLETCH_ARM")
    invoke_gcc_arm(args)
  elif "-DFLETCH_ARM64" in args:
    invoke_gcc_arm64(args)
  elif "-L/FLETCH_ARM64" in args:
    args.remove("-L/FLETCH_ARM64")
    invoke_gcc_arm64(args)
  else:
    invoke_gcc(args)


if __name__ == '__main__':
  main()
