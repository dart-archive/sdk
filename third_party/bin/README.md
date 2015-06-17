<!---
Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
for details. All rights reserved. Use of this source code is governed by a
BSD-style license that can be found in the LICENSE.md file.
-->

We use a patched version of the Dart VM at the moment, because
  * Testing is much faster using vfork()
  * The persistent process / daemon uses Unix Domain Sockets

The patches (our source of truth) can be found in
  * patches/vfork.diff
  * patches/unix_domain_socket.diff

The changes are rougly based on the following CLs
  * https://codereview.chromium.org/1095903003/
  * https://codereview.chromium.org/1061283003/

In order to have a single binary per OS-Arch combination, we use the
same Dart VM executable for driving the testing scripts and for driving
the persistent process.

[Please note that this changes our normally used 32-bit binary for driving the
testing scripts in tools/testing/bin/... to be a 64-bit binary.]

We built the Dart VM for the following configurations
  * macos-release-x64
  * linux-release-x64
  * linux-release-arm

The machine where we build the binaries should be
  * Version 10.8.5 for MacOS
  * Version 12.04.3 for Ubuntu Linux

=> This allows us to run these binaries also on older versions of MacOS/Ubuntu
and avoids issues (e.g. too recent version of libc).

Compiling the Dart VM with the patches should roughly follow the following
procedure:

```bash
set -x

mkdir -p dart-build
cd dart-build

gclient config https://github.com/dart-lang/sdk.git
gclient sync

# Sync to version 1.11.0-dev.5.2 (aka 23736d3630da614c655d0569e1ba5af2021b1c61)
gclient sync --with_branch_heads --revision \
  23736d3630da614c655d0569e1ba5af2021b1c61

cd sdk
git checkout -b patch

patch -p1 < ../../patches/vfork.diff
git commit -a -m'Using vfork() for faster testing'

patch -p1 < ../../patches/unix_domain_socket.diff
git commit -a -m'Support for unix domain socket for faster testing'

# On MacOS
./tools/build.py -mrelease -ax64
./tools/test.py -mrelease -ax64
strip -x xcodebuild/ReleaseX64/dart

# On Linux - intel
./tools/build.py -mrelease -ax64
./tools/test.py -mrelease -ax64
strip out/ReleaseX64/dart

# On Linux - arm
./tools/build.py -mrelease -aarm
arm-linux-gnueabihf-strip out/ReleaseXARM/dart
```

After building the binaries they need to be uploaded to GoogleCloudStorage and
their sha1 file needs to be checked into the repository.

Before uploading one needs to ensure one has setup the correct
`BOTO_CONFIG` environment variable pointing to a valid boto file which has
permission to write to the GCS bucket.
(Please note there might be issues about which version of gsutil is used -
from `PATH` or `depot_tools`)

Then one needs to mark the binaries as executable (this executable bit will be
preserved when downloading the binaries again -- it is stored via metadata on
the GCS objects).

Afterwards the binaries can be uploaded.

The last two steps are described here:

```
# On MacOS
chmod +x xcodebuild/ReleaseX64/dart
upload_to_google_storage.py -b dart-dependencies-fletch \
  xcodebuild/ReleaseX64/dart

# On Linux - intel
chmod +x out/ReleaseX64/dart
upload_to_google_storage.py -b dart-dependencies-fletch \
  out/ReleaseX64/dart

# On Linux - arm
chmod +x out/ReleaseXARM/dart
upload_to_google_storage.py -b dart-dependencies-fletch \
   out/ReleaseXARM/dart
```

The sha1 files need to be checked into the repository at
  * `third_party/bin/{linux,mac}/...`
  * `tools/testing/bin/{linux,mac}/...`

It is highly recommended to test that everything worked, by
  * ensuring only sha1 files have been changed
  * deleting the binaries
  * re-running `gclient runhooks` to download new binaries
  * building & running ./tools/test.py

