// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_FLETCH_API_H_
#define INCLUDE_FLETCH_API_H_

#ifdef __cplusplus
#define FLETCH_EXPORT extern "C" __attribute__((visibility("default")))
#else
#define FLETCH_EXPORT __attribute__((visibility("default")))
#endif

// Setup must be called before using any of the other API methods.
FLETCH_EXPORT void FletchSetup();

// TearDown should be called when an application is done using the
// fletch API in order to free up resources.
FLETCH_EXPORT void FletchTearDown();

// Load the program from the snapshot, start a process from that
// program, and run main in that process.
FLETCH_EXPORT void FletchRunSnapshot(unsigned char* snapshot, int length);

// Load the snapshot from the file, load the program from the
// snapshot, start a process from that program, and run main in that
// process.
FLETCH_EXPORT void FletchRunSnapshotFromFile(const char* path);

#endif  // INCLUDE_SERVICE_API_H_
