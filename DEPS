# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.


vars = {
  # Use this googlecode_url variable only if there is an internal mirror for it.
  # If you do not know, use the full path while defining your new deps entry.
  "googlecode_url": "http://%s.googlecode.com/svn",

  "clang_rev": "@43229",
  "dart_rev": "@44800",
  "gyp_rev": "@1752",
}

deps = {
  # Stuff needed for GYP to run.
  "third_party/gyp":
      (Var("googlecode_url") % "gyp") + "/trunk" + Var("gyp_rev"),

  "third_party/clang":
      ((Var("googlecode_url") % "dart") + "/third_party/clang" +
       Var("clang_rev")),

  "dart":
      ((Var("googlecode_url") % "dart") + "/branches/bleeding_edge/dart" +
       Var("dart_rev")),
}

# To include Mac deps on other OSes, add this to your .gclient file:
#
#     target_os = [ "mac" ]
#
# To ignore the host OS, add this:
#
#     target_os_only = True
deps_os = {
  "android": {
  },

  "mac": {
  },

  "unix": {
  },

  "win": {
  },
}

hooks = [
  {
    'name': 'third_party_libs',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      '-r',
      '--auto_platform',
      'fletch/third_party/libs',
    ],
  },
  {
    'name': 'third_party_binaries',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      '-r',
      '--auto_platform',
      'fletch/third_party/bin',
    ],
  },
  {
    'name': 'dart_test_binary',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      '-r',
      '--auto_platform',
      'fletch/tools/testing/bin',
    ],
  },
  {
    'name': 'GYP',
    'pattern': '.',
    'action': [
      'ninja', '-C', 'fletch',
    ],
  },
]
