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

// Wait for a debugger connection. The debugger will build the program
// to run in the VM and start it.
FLETCH_EXPORT void FletchWaitForDebuggerConnection(int port);

// Load the program from the snapshot, start a process from that
// program, and run main in that process.
FLETCH_EXPORT void FletchRunSnapshot(unsigned char* snapshot, int length);

// Load the snapshot from the file, load the program from the
// snapshot, start a process from that program, and run main in that
// process.
FLETCH_EXPORT void FletchRunSnapshotFromFile(const char* path);

// Add a default shared library for the dart:ffi foreign lookups.
// More than one default shared library can be added. The libraries
// are used for foreign lookups where no library has been specified.
// The libraries are searched in the order in which they are added.
// The library string must be null-terminated and Fletch does not
// take over ownership of the passed in string.
FLETCH_EXPORT void FletchAddDefaultSharedLibrary(const char* library);

#endif  // INCLUDE_FLETCH_API_H_
