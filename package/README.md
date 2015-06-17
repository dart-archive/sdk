<!---
Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
for details. All rights reserved. Use of this source code is governed by a
BSD-style license that can be found in the LICENSE.md file.
-->

This is the package root used when testing fletch. This directory should contain only symlinks to packages that have been added using one of the following mechanisms:

* A package which is part of fletch and lives in ../pkg. For example, a symlink to ../pkg/fletchc/lib.

* A Dart SDK package imported from the Dart SDK repository, for example, a symlink to ../../dart/pkg/PACKAGE_NAME/lib.

* A third-part package imported via gclient, for example, a symlink to ../../third_party/PACKAGE_NAME/lib.

* A Dart SDK or third-party package with (temporary) local modifications necessary for getting it running on Dart. Such a package should live in ../pkg and have a README-fletch.md file which mentions: 1) the repository and commit from where it was copied, and 2) a diff or CL detailing the local changes. For example, see [pkg/expect](../pkg/expect/README-fletch.md).