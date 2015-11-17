# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.


vars = {
  # NOTE: This revision will be used for looking at
  #   gs://chromium-browser-clang/Mac/clang-<rev>-1.tgz
  #   gs://chromium-browser-clang/Linux_x64/clang-<rev>-1.tgz
  "clang_rev": "245965",

  "github_url": "https://github.com/%s.git",

  "gyp_rev": "@6ee91ad8659871916f9aa840d42e1513befdf638",
  "persistent_rev": "@55daae1a038188c49e36a64e7ef132c4861da3d8",

  # Used by pkg/immi_samples.
  "crypto_rev": "@dd0ff8b95269b11f7bd925d2f58e5e938c1f03fc",

  # Used by fletch_tests.
  "isolate_tag": "@0.2.2",

  # When updating this, please remember:
  # 1. to use a commit on the branch "_temporary_fletch_patches".
  # 2. update package revisions below.
  "dart_rev": "@f3ca4b2e0acf43b3ac8642cdda5afc10f4e503bb",

  # Please copy these package revisions from ../dart/DEPS when updating
  # dart_rev:
  "package_config_tag": "@0.1.3",
  "path_tag": "@1.3.6",
  "charcode_tag": "@1.1.0",
  "args_tag": "@0.13.0",

  "lk_rev": "@b822b1f64f4a98ad10c9794e8ed20ab8ccba3d4a",

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

  "chromium_git": "https://chromium.googlesource.com",
}

deps = {
  # Stuff needed for GYP to run.
  "fletch/third_party/gyp":
      Var('chromium_git') + '/external/gyp.git' + Var("gyp_rev"),

  "fletch/third_party/dart":
      (Var("github_mirror") % "sdk") + Var("dart_rev"),

  "fletch/third_party/package_config":
      (Var("github_mirror") % "package_config") + Var("package_config_tag"),

  "fletch/third_party/args":
      (Var("github_mirror") % "args") + Var("args_tag"),

  "fletch/third_party/charcode":
      (Var("github_mirror") % "charcode") + Var("charcode_tag"),

  "fletch/third_party/path":
      (Var("github_mirror") % "path") + Var("path_tag"),

  "fletch/third_party/persistent":
      (Var("github_url") % "polux/persistent") + Var("persistent_rev"),

  "fletch/third_party/crypto":
      (Var("github_mirror") % "crypto") + Var("crypto_rev"),

  "fletch/third_party/lk/lk-downstream":
      (Var("github_url") % "travisg/lk") + Var("lk_rev"),

  "fletch/third_party/isolate":
      "https://github.com/dart-lang/isolate.git" + Var("isolate_tag"),

  "wiki": (Var("github_url") % "dart-lang/fletch.wiki"),
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
    'name': 'mdns_native_extension_binaries',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      'fletch/pkg/mdns/lib/native',
    ],
  },
  {
    'name': 'third_party_qemu',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      '-r',
      '-u',
      '--auto_platform',
      'fletch/third_party/qemu',
    ],
  },
  {
    'name': 'third_party_openocd',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      '-r',
      '-u',
      '--auto_platform',
      'fletch/third_party/openocd',
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
