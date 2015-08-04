<!---
Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
for details. All rights reserved. Use of this source code is governed by a
BSD-style license that can be found in the LICENSE.md file.
-->

The test files in this directory aren't really dart files. They simply
specify snapshot tests that we want to run using:
```
// FletchSnapshotOptions=
```

We assume (and validate) that two options are specified, space
separated, one is the file from which we generate a snapshot and the
second is the binary we use to test the snapshot, e.g.:
```
// FletchSnapshotOptions=samples/todomvc/todomvc.dart todomvc_sample
```
