<!---
Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
for details. All rights reserved. Use of this source code is governed by a
BSD-style license that can be found in the LICENSE.md file.
-->

We use a patched version of the Dart VM at the moment, because
  * Testing is much faster using vfork()
  * The persistent process / daemon uses Unix Domain Sockets

These patches are tracked in a [branch of the Dart
SDK](https://github.com/dart-lang/sdk/tree/_temporary_fletch_patches). This
branch is the source of truth.

In order to have a single binary per OS-Arch combination, we use the
same Dart VM executable for driving the testing scripts and for driving
the persistent process.

Please note that this changes our normally used 32-bit binary for driving the
testing scripts in tools/testing/bin/... to be a 64-bit binary.

We built the Dart VM for the following configurations
  * macos-release-x64
  * linux-release-x64
  * linux-release-arm

The machine where we build the binaries should be
  * Version 10.8.5 for MacOS
  * Version 12.04.3 for Ubuntu Linux

This allows us to run these binaries also on older versions of MacOS/Ubuntu and
avoids issues (e.g. too recent version of libc).

Compiling the Dart VM should roughly follow the following procedure:

```bash
mkdir dart-build
cd dart-build

gclient config https://github.com/dart-lang/sdk.git

gclient sync --with_branch_heads --revision origin/_temporary_fletch_patches

# On MacOS
./tools/build.py -mrelease -ax64 create_sdk
./tools/test.py -mrelease -ax64

# On Linux - intel
./tools/build.py -mrelease -ax64 create_sdk
./tools/test.py -mrelease -ax64

# On Linux - arm
./tools/build.py -mrelease -aarm runtime
```

After building the binaries they need to be uploaded to GoogleCloudStorage and
their sha1 file needs to be checked into the repository.

Before uploading one needs to ensure one has setup the correct
`BOTO_CONFIG` environment variable pointing to a valid boto file which has
permission to write to the GCS bucket.
Please note there might be issues about which version of gsutil is used -
from `PATH` or `depot_tools`. Also note that you most likely will have to
use `gsutil.py config` (with the `gsutil.py` from `depot_tools`) and neither
`gcloud auth login` nor `gsutil config` to make authentication work with
`upload_to_google_storage.py`.

Then one needs to mark the binaries as executable (this executable bit will be
preserved when downloading the binaries again -- it is stored via metadata on
the GCS objects).

Afterwards the binaries can be uploaded.

The last two steps are described here:

```
# On MacOS
chmod +x xcodebuild/ReleaseX64/dart-sdk/bin/dart
upload_to_google_storage.py -b dart-dependencies-fletch \
  xcodebuild/ReleaseX64/dart-sdk/bin/dart

# On Linux - intel
chmod +x out/ReleaseX64/dart-sdk/bin/dart
upload_to_google_storage.py -b dart-dependencies-fletch \
  out/ReleaseX64/dart-sdk/bin/dart

# On Linux - arm
chmod +x out/ReleaseXARM/dart
arm-linux-gnueabihf-strip out/ReleaseXARM/dart
upload_to_google_storage.py -b dart-dependencies-fletch \
   out/ReleaseXARM/dart
```

The sha1 files need to be checked into the repository at
  * `third_party/bin/linux/dart.sha1`
  * `third_party/bin/linux/dart-arm.sha1`
  * `third_party/bin/mac/dart.sha1`
  * `tools/testing/bin/linux/dart.sha1`
  * `tools/testing/bin/linux/dart-arm.sha1`
  * `tools/testing/bin/mac/dart.sha1`

It is highly recommended to test that everything worked, by
  * ensuring only sha1 files have been changed
  * deleting the binaries
  * re-running `gclient runhooks` to download new binaries
  * building & running ./tools/test.py
