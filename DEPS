# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.


vars = {
  # Use this googlecode_url variable only if there is an internal mirror for it.
  # If you do not know, use the full path while defining your new deps entry.
  "googlecode_url": "http://%s.googlecode.com/svn",

  "clang_rev": "@43229",
  "gyp_rev": "@1752",
}

deps = {
  # Stuff needed for GYP to run.
  "fletch/third_party/gyp":
      (Var("googlecode_url") % "gyp") + "/trunk" + Var("gyp_rev"),

  "fletch/third_party/clang":
      ((Var("googlecode_url") % "dart") + "/third_party/clang" +
       Var("clang_rev")),
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
    'name': 'libtcmalloc_minimal_linux_x64',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '--no_auth',
                '--no_resume',
                '--platform=linux*',
                '--bucket', 'dart-dependencies-fletch',
                '-s', 'fletch/third_party/libs/linux/x64/libtcmalloc_minimal.a.sha1',
    ],
  },
  {
    'name': 'libtcmalloc_minimal_linux_x86',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '--no_auth',
                '--no_resume',
                '--platform=linux*',
                '--bucket', 'dart-dependencies-fletch',
                '-s', 'fletch/third_party/libs/linux/x86/libtcmalloc_minimal.a.sha1',
    ],
  },
  {
    'name': 'libtcmalloc_minimal_macos_x64',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '--no_auth',
                '--no_resume',
                '--platform=darwin',
                '--bucket', 'dart-dependencies-fletch',
                '-s', 'fletch/third_party/libs/macos/x64/libtcmalloc_minimal.a.sha1',
    ],
  },
  {
    'name': 'libtcmalloc_minimal_macos_x86',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '--no_auth',
                '--no_resume',
                '--platform=darwin',
                '--bucket', 'dart-dependencies-fletch',
                '-s', 'fletch/third_party/libs/macos/x86/libtcmalloc_minimal.a.sha1',
    ],
  },
  {
    'name': 'dart_test_binary_linux',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '--no_auth',
                '--no_resume',
                '--platform=linux*',
                '--bucket', 'dart-dependencies-fletch',
                '-s', 'fletch/tools/testing/bin/linux/dart.sha1',
    ],
  },
  {
    'name': 'dart_test_binary_macos',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '--no_auth',
                '--no_resume',
                '--platform=darwin',
                '--bucket', 'dart-dependencies-fletch',
                '-s', 'fletch/tools/testing/bin/macos/dart.sha1',
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
