# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.


vars = {
  # NOTE: This revision will be used for looking at
  #   gs://chromium-browser-clang/Mac/clang-<rev>-1.tgz
  #   gs://chromium-browser-clang/Linux_x64/clang-<rev>-1.tgz
  "clang_rev": "239765",

  # Use this googlecode_url variable only if there is an internal mirror for it.
  # If you do not know, use the full path while defining your new deps entry.
  "googlecode_url": "http://%s.googlecode.com/svn",
  "github_url": "https://github.com/%s.git",

  "gyp_rev": "@1752",
  "persistent_rev": "@55daae1a038188c49e36a64e7ef132c4861da3d8",

  # When updating this, please remember:
  # 1. to use a commit is on the _temporary_fletch_patches branch.
  # 2. update package revisions below.
  "dart_rev": "@b2ccdc92f8f87e8ccdac6a7468e2e69ca726fbc9",

  # Please copy these from ../dart/DEPS when updating dart_rev:
  "package_config_tag": "@0.1.1",
  "path_rev": "@93b3e2aa1db0ac0c8bab9d341588d77acda60320",
  "charcode_tag": "@1.1.0",

  # We use mirrors of all github repos to guarantee reproducibility and
  # consistency between what users see and what the bots see.
  # We need the mirrors to not have 100+ bots pulling github constantly.
  # We mirror our github repos on chromium git servers.
  # DO NOT use this var if you don't see a mirror here:
  #   https://chromium.googlesource.com/
  # named like:
  #   external/github.com/dart-lang/NAME
  # It is ok to add a dependency directly on dart-lang (dart-lang only)
  # github repo until the mirror has been created, but please do file a bug
  # against infra to make that happen.
  "github_mirror":
      "https://chromium.googlesource.com/external/github.com/dart-lang/%s.git",
}

deps = {
  # Stuff needed for GYP to run.
  "third_party/gyp":
      (Var("googlecode_url") % "gyp") + "/trunk" + Var("gyp_rev"),

  "dart":
      ((Var("github_url") % "dart-lang/sdk") + "/" + Var("dart_rev")),

  "third_party/package_config":
      (Var("github_mirror") % "package_config") + Var("package_config_tag"),

  "third_party/charcode":
      (Var("github_mirror") % "charcode") + Var("charcode_tag"),

  "third_party/path":
      (Var("github_mirror") % "path") + Var("path_rev"),

  "third_party/persistent":
      (Var("github_url") % "polux/persistent") + Var("persistent_rev"),
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
    'name': 'lazy_update_clang',
    'pattern': '.',
    'action': [
      'python',
      'fletch/tools/clang_update.py',
      '--revision=' + Var("clang_rev"),
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
