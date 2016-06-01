// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

This is a native extension used by the dartino debugger to access the serial
port.

When testing changes on Mac OS:

$ ninja -C out/ReleaseX64
$ src/pkg/serial_port/copy_dylib.sh

When the new .dylib file is working upload it to GCS

$ src/pkg/serial_port/upload_dylib.sh

The resulting .sha1 file (in pkg/power management/lib/native) is then
updated and checked in.

On Linux replace _dylib with _so in the two script names.
