<!---
Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
for details. All rights reserved. Use of this source code is governed by a
BSD-style license that can be found in the LICENSE.md file.
-->

We use the DartVM for running the persistent dartino process and the testing
scripts. The DartVM binaries we use are declared in sha1 files which
`gclient runhooks` updates.

In order to have a single binary per OS-Arch combination, we use the
same Dart VM executable for driving the testing scripts and for driving
the persistent process.

Please note that this changes our normally used 32-bit binary for driving the
testing scripts in tools/testing/bin/... to be a 64-bit binary.

To download the binaries, upload them to cloudstorage (which will generate the
sha1 files), and copy the sha1 files to the testing directory, use the script in
`tools/tools/update-dartino-binaries.sh`.

Before uploading with the script one needs to ensure one has setup the correct
`BOTO_CONFIG` environment variable pointing to a valid boto file which has
permission to write to the GCS bucket.  To ensure that you have the right
permissions you should run '`gsutil.py config` (with the `gsutil.py` from
`depot_tools`) and neither `gcloud auth login` nor `gsutil config` to make
authentication work with `upload_to_google_storage.py`. If you don't have access
to upload ask ricow@ to change the acl.

It is highly recommended to test that everything worked, by
  * ensuring only sha1 files have been changed
  * deleting the binaries
  * re-running `gclient runhooks` to download new binaries
  * verify that they have the correct version by running
  `third_party/bin/<OS>/dart --version`
  * building & running ./tools/test.py
