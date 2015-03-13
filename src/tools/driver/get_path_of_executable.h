// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_TOOLS_DRIVER_GET_PATH_OF_EXECUTABLE_H_
#define SRC_TOOLS_DRIVER_GET_PATH_OF_EXECUTABLE_H_

namespace fletch {

// Computes the path of of this executable. This is similar to argv[0], but
// since argv[0] is provided by the calling process, argv[0] may be an
// arbitrary value where as this method uses an OS-dependent method of finding
// the real path.
void GetPathOfExecutable(char* path, size_t path_length);

}  // namespace fletch

#endif  // SRC_TOOLS_DRIVER_GET_PATH_OF_EXECUTABLE_H_
