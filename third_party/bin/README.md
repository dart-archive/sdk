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

We don't build these locally, but rely on 3 buildbots for building them in
a controlled environment.

There are download links on the 3 sdk patched bots, to update the checked in
versions download the 3 binaries and put them in the platform specific binaries
under third_party/bin/linux/{dart,dart-arm} and third_party/bin/mac/dart.

The binaries then need to be uploaded to GoogleCloudStorage and
their sha1 file needs to be checked into the repository.

Before uploading one needs to ensure one has setup the correct
`BOTO_CONFIG` environment variable pointing to a valid boto file which
has permission to write to the GCS bucket.  To ensure that you have
the right permissions you should run '`gsutil.py config` (with the
`gsutil.py` from `depot_tools`) and neither
`gcloud auth login` nor `gsutil config` to make authentication work with
`upload_to_google_storage.py`. If you don't have access to upload ask ricow@
to change the acl.

Then one needs to mark the binaries as executable (this executable bit will be
preserved when downloading the binaries again -- it is stored via metadata on
the GCS objects). 'chmod +x' on the files before uploading.

Afterwards the binaries can be uploaded.

```
cd  third_party/bin/linux
upload_to_google_storage.py -b dart-dependencies-fletch dart
cp dart.sha1 ../../../tools/testing/bin/linux/dart.sha1
upload_to_google_storage.py -b dart-dependencies-fletch dart-arm
cp dart-arm.sha1 ../../../tools/testing/bin/linux/dart-arm.sha1
cd ../mac
upload_to_google_storage.py -b dart-dependencies-fletch dart
cp dart.sha1 ../../../tools/testing/bin/mac/dart.sha1
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
