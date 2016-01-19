# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.


vars = {
  # NOTE: This revision will be used for looking at
  #   gs://chromium-browser-clang/Mac/clang-<rev>-1.tgz
  #   gs://chromium-browser-clang/Linux_x64/clang-<rev>-1.tgz
  "clang_rev": "245965",

  "buildtools_revision": "@818123dac34899ec230840936fc15b8b2b5556f9",

  "github_url": "https://github.com/%s.git",

  "gyp_rev": "@6fb8bd829f0ca8fd432fd85ede788b6881c4f09f",
  "persistent_rev": "@55daae1a038188c49e36a64e7ef132c4861da3d8",

  # Used by pkg/immi_samples.
  "crypto_rev": "@dd0ff8b95269b11f7bd925d2f58e5e938c1f03fc",

  # Used by fletch_tests.
  "isolate_tag": "@0.2.2",

  # When updating this, please remember:
  # 1. to use a commit on the branch "_temporary_fletch_patches".
  # 2. update package revisions below.
  # 3. Upload new binaries and update the `third_party/bin` sha-hash-files as
  #    described in `third_party/bin/README.md`.
  "dart_rev": "@d2e77fb81d529a236f916ea9a5e9ff5da3a50b56",

  # Please copy these package revisions from ../dart/DEPS when updating
  # dart_rev:
  "package_config_tag": "@0.1.3",
  "path_tag": "@1.3.6",
  "charcode_tag": "@1.1.0",
  "args_tag": "@0.13.0",
  "dart2js_info_rev" : "@0a221eaf16aec3879c45719de656680ccb80d8a1",
  "pub_semver_tag": "@1.2.1",
  "collection_rev": "@1da9a07f32efa2ba0c391b289e2037391e31da0e",

  "lk_rev": "@6cdc5cd1daaf22f56422301d3dac67c3573ef290",

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
  # Clang format support.
  "buildtools":
     Var('chromium_git') + '/chromium/buildtools.git' +
     Var('buildtools_revision'),

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

  "fletch/third_party/dart2js_info":
      "https://github.com/dart-lang/dart2js_info.git" + Var("dart2js_info_rev"),

  "fletch/third_party/pub_semver":
      (Var("github_mirror") % "pub_semver") + Var("pub_semver_tag"),

  "fletch/third_party/collection":
      (Var("github_mirror") % "collection") + Var("collection_rev"),

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
    'fletch/third_party/cygwin':
      Var('chromium_git') + '/chromium/deps/cygwin.git' + '@' +
      'c89e446b273697fadf3a10ff1007a97c0b7de6df',

    'fletch/third_party/yasm/source/patched-yasm':
      Var('chromium_git') + '/chromium/deps/yasm/patched-yasm.git' + '@' +
      '4671120cd8558ce62ee8672ebf3eb6f5216f909b',
  },

}

hooks = [
  {
    'name': 'third_party_binaries',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '-q',
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
      '-q',
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
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      'fletch/pkg/mdns/lib/native',
    ],
  },
  {
    'name': 'power_management_native_extension_binaries',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      'fletch/pkg/power_management/lib/native',
    ],
  },
  {
    # Update the Windows toolchain if necessary.
    'name': 'win_toolchain',
    'pattern': '.',
    'action': ['python',
               'fletch/tools/vs_dependency/vs_toolchain.py',
               'update'],
  },
  {
    'name': 'third_party_qemu',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '-q',
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
      '-q',
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
    'name': 'third_party_gcc_arm_embedded',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      '-r',
      '-u',
      '--auto_platform',
      'fletch/third_party/gcc-arm-embedded',
    ],
  },
  {
    'name': 'third_party_stm',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dart-dependencies-fletch',
      '-d',
      '-r',
      '-u',
      'fletch/third_party/stm',
    ],
  },
  # Pull clang-format binaries using checked-in hashes.
  {
    'name': 'clang_format_win',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '-q',
                '--no_resume',
                '--platform=win32',
                '--no_auth',
                '--bucket', 'chromium-clang-format',
                '-s', 'buildtools/win/clang-format.exe.sha1',
    ],
  },
  {
    'name': 'clang_format_mac',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '-q',
                '--no_resume',
                '--platform=darwin',
                '--no_auth',
                '--bucket', 'chromium-clang-format',
                '-s', 'buildtools/mac/clang-format.sha1',
    ],
  },
  {
    'name': 'clang_format_linux',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '-q',
                '--no_resume',
                '--platform=linux*',
                '--no_auth',
                '--bucket', 'chromium-clang-format',
                '-s', 'buildtools/linux64/clang-format.sha1',
    ],
  },
  {
    'name': 'mbedtls',
    'pattern': '.',
    'action': [ 'download_from_google_storage',
                '-q',
                '--no_resume',
                '--no_auth',
                '--bucket', 'dart-dependencies-fletch',
                '-u',
                '-s', 'fletch/third_party/mbedtls/mbedtls.tar.gz.sha1',
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
      'python',
      'fletch/tools/run-ninja.py',
      '-C',
      'fletch',
    ],
  },
]
