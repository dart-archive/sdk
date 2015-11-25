#!/usr/bin/python

# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import os
import sys
import utils
import subprocess

def is_executable(path):
  return os.path.isfile(path) and os.access(path, os.X_OK)

def which(program):
  for path in os.environ["PATH"].split(os.pathsep):
    path = path.strip('"')
    program_path = os.path.join(path, program)
    if is_executable(program_path):
      return program_path

  return None

def relative_to_fletch_root(*target):
  fletch_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
  return os.path.join(fletch_path, *target)

def invoke_clang(args):
  os_name = utils.GuessOS()
  clang_bin = relative_to_fletch_root(
    "third_party", "clang", os_name, "bin", "clang")
  if os_name == "macos":
    os_name = "mac"
    args.extend([
      '-isysroot',
      subprocess.check_output(['xcrun', '--show-sdk-path']).strip()])
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

def invoke_gcc_cmsis(args):
  path = "/usr/local/gcc-arm-none-eabi-4_9-2015q2/bin/arm-none-eabi-g++"
  subprocess.check_call([path] + args)

def invoke_gcc_arm_embedded(args):
  os_name = utils.GuessOS()
  gcc_arm_embedded_bin = relative_to_fletch_root(
    "third_party", "gcc-arm-embedded", os_name, "gcc-arm-embedded", "bin",
    "arm-none-eabi-g++")
  if not os.path.exists(gcc_arm_embedded_bin):
    gcc_arm_embedded_download = relative_to_fletch_root(
      "third_party", "gcc-arm-embedded", "download")
    print "Missing toolchain run %s to download" % gcc_arm_embedded_download
  args.insert(0, gcc_arm_embedded_bin)
  os.execv(gcc_arm_embedded_bin, args)

def invoke_gcc_lk(args):
  if which("arm-eabi-g++") is not None:
    args.insert(0, "arm-eabi-g++")
    os.execvp("arm-eabi-g++", args)
  else:
    args.insert(0, "arm-none-eabi-g++")
    os.execvp("arm-none-eabi-g++", args)

def main():
  args = sys.argv[1:]
  if "-L/FLETCH_ASAN" in args:
    args.remove("-L/FLETCH_ASAN")
    args.insert(0, '-fsanitize=address')
    if "-L/FLETCH_CLANG" in args:
      args.insert(0, '-fsanitize-undefined-trap-on-error')
  if "-DFLETCH_CLANG" in args:
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
  elif "-DFLETCH_CMSIS" in args:
    invoke_gcc_cmsis(args)
  elif "-L/FLETCH_CMSIS" in args:
    args.remove("-L/FLETCH_CMSIS")
    invoke_gcc_cmsis(args)
  elif "-DFLETCH_STM" in args:
    invoke_gcc_arm_embedded(args)
  elif "-L/FLETCH_STM" in args:
    args.remove("-L/FLETCH_STM")
    invoke_gcc_arm_embedded(args)
  elif "-DFLETCH_LK" in args:
    invoke_gcc_lk(args)
  elif "-L/FLETCH_LK" in args:
    args.remove("-L/FLETCH_LK")
    invoke_gcc_lk(args)
  else:
    invoke_gcc(args)

if __name__ == '__main__':
  main()
