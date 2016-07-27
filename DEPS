# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
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

  # Used by dartino_tests.
  "isolate_tag": "@0.2.2",

  "instrumentation_client_rev": "@f06dca45223695f7828b9f045ef4317833fb2dba",

  "dart_rev": "@9fff9a162914b97dd4bc48f5c2386f01a1232bad",

  # Please copy these package revisions from third_party/dart/DEPS when
  # updating dart_rev:
  "package_config_tag": "@0.1.3",
  "path_tag": "@1.3.6",
  "charcode_tag": "@1.1.0",
  "args_tag": "@0.13.4",
  "dart2js_info_rev" : "@0a221eaf16aec3879c45719de656680ccb80d8a1",
  "pub_semver_tag": "@1.2.1",
  "collection_tag": "@1.6.0",

  "lk_rev": "@0f0b4959ad25cb1a2bffd1a2eba487b88a602c96",

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
  "sdk/third_party/gyp":
      Var('chromium_git') + '/external/gyp.git' + Var("gyp_rev"),

  "sdk/third_party/dart":
      (Var("github_mirror") % "sdk") + Var("dart_rev"),

  "sdk/third_party/package_config":
      (Var("github_mirror") % "package_config") + Var("package_config_tag"),

  "sdk/third_party/args":
      (Var("github_mirror") % "args") + Var("args_tag"),

  "sdk/third_party/charcode":
      (Var("github_mirror") % "charcode") + Var("charcode_tag"),

  "sdk/third_party/path":
      (Var("github_mirror") % "path") + Var("path_tag"),

  "sdk/third_party/persistent":
      (Var("github_url") % "polux/persistent") + Var("persistent_rev"),

  "sdk/third_party/crypto":
      (Var("github_mirror") % "crypto") + Var("crypto_rev"),

  "sdk/third_party/lk/lk-upstream":
      (Var("github_url") % "littlekernel/lk") + Var("lk_rev"),

  "sdk/third_party/isolate":
      "https://github.com/dart-lang/isolate.git" + Var("isolate_tag"),

  "sdk/third_party/dart2js_info":
      "https://github.com/dart-lang/dart2js_info.git" + Var("dart2js_info_rev"),

  "sdk/third_party/instrumentation_client":
      "https://github.com/dart-lang/instrumentation_client.git"
      + Var("instrumentation_client_rev"),

  "sdk/third_party/pub_semver":
      (Var("github_mirror") % "pub_semver") + Var("pub_semver_tag"),

  "sdk/third_party/collection":
      (Var("github_mirror") % "collection") + Var("collection_tag"),

  "wiki": (Var("github_url") % "dartino/sdk.wiki"),
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
    'sdk/third_party/cygwin':
      Var('chromium_git') + '/chromium/deps/cygwin.git' + '@' +
      'c89e446b273697fadf3a10ff1007a97c0b7de6df',

    'sdk/third_party/yasm/source/patched-yasm':
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
      'dartino-dependencies',
      '-d',
      '-r',
      '--auto_platform',
      'sdk/third_party/bin',
    ],
  },
  {
    "name": "checked_in_dart_sdks",
    "pattern": ".",
    "action": [
      "download_from_google_storage",
      "-q",
      "--no_auth",
      "--no_resume",
      "--bucket",
      "dart-dependencies",
      "--directory",
      "--recursive",
      "--auto_platform",
      "--extract",
      "sdk/third_party/dart-sdk",
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
      'dartino-dependencies',
      '-d',
      '-r',
      '--auto_platform',
      'sdk/tools/testing/bin',
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
      'dartino-dependencies',
      '-d',
      'sdk/pkg/mdns/lib/native',
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
      'dartino-dependencies',
      '-d',
      'sdk/pkg/power_management/lib/native',
    ],
  },
  {
    'name': 'serial_port_binaries',
    'pattern': '.',
    'action': [
      'download_from_google_storage',
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dartino-dependencies',
      '-d',
      'sdk/third_party/serial_port/lib/src/',
    ],
  },
  {
    # Update the Windows toolchain if necessary.
    'name': 'win_toolchain',
    'pattern': '.',
    'action': ['python',
               'sdk/tools/vs_dependency/vs_toolchain.py',
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
      'dartino-dependencies',
      '-d',
      '-r',
      '-u',
      '--auto_platform',
      'sdk/third_party/qemu',
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
      'dartino-dependencies',
      '-d',
      '-r',
      '-u',
      '--auto_platform',
      'sdk/third_party/openocd',
    ],
  },
  {
    'name': 'third_party_gcc_arm_embedded',
    'pattern': '.',
    'action': [
      'python',
      'sdk/tools/not_on_arm.py',
      'download_from_google_storage',
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dartino-dependencies',
      '-d',
      '-r',
      '-u',
      '--auto_platform',
      'sdk/third_party/gcc-arm-embedded',
    ],
  },
  {
    'name': 'third_party_stm',
    'pattern': '.',
    'action': [
      'python',
      'sdk/tools/not_on_arm.py',
      'download_from_google_storage',
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dartino-dependencies',
      '-d',
      '-u',
      'sdk/third_party/stm',
    ],
  },
  {
    'name': 'third_party_freertos',
    'pattern': '.',
    'action': [
      'python',
      'sdk/tools/not_on_arm.py',
      'download_from_google_storage',
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dartino-dependencies',
      '-d',
      '-r',
      '-u',
      'sdk/third_party/freertos',
    ],
  },
  {
    'name': 'third_party_emul8',
    'pattern': '.',
    'action': [
      'python',
      'sdk/tools/not_on_arm.py',
      'download_from_google_storage',
      '-q',
      '--no_auth',
      '--no_resume',
      '--bucket',
      'dartino-dependencies',
      '-d',
      '-r',
      '-u',
      '--auto_platform',
      'sdk/third_party/emul8',
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
    'action': [ 'python',
                'sdk/tools/not_on_arm.py',
                'download_from_google_storage',
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
                '--bucket', 'dartino-dependencies',
                '-u',
                '-s', 'sdk/third_party/mbedtls/mbedtls.tar.gz.sha1',
    ],
  },
  {
    'name': 'lazy_update_clang',
    'pattern': '.',
    'action': [
      'python',
      'sdk/tools/clang_update.py',
      '--revision=' + Var("clang_rev"),
    ],
  },
  {
    'name': 'GYP',
    'pattern': '.',
    'action': [
      'python',
      'sdk/tools/run-ninja.py',
      '-C',
      'sdk',
    ],
  },
]
