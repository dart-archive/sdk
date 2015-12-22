// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_FLETCH_API_H_
#define INCLUDE_FLETCH_API_H_

#include <stdbool.h>

#ifdef _MSC_VER
// TODO(herhut): Do we need a __declspec here for Windows?
#define FLETCH_VISIBILITY_DEFAULT
#else
#define FLETCH_VISIBILITY_DEFAULT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
#define FLETCH_EXPORT extern "C" FLETCH_VISIBILITY_DEFAULT
#else
#define FLETCH_EXPORT FLETCH_VISIBILITY_DEFAULT
#endif

typedef void* FletchProgram;
typedef void* FletchPrintInterceptor;
typedef void (*PrintInterceptionFunction)(
    const char* message, int out, void* data);

// Setup must be called before using any of the other API methods.
FLETCH_EXPORT void FletchSetup(void);

// TearDown should be called when an application is done using the
// fletch API in order to free up resources.
FLETCH_EXPORT void FletchTearDown(void);

// Wait for a debugger connection. The debugger will build the program
// to run in the VM and start it.
FLETCH_EXPORT void FletchWaitForDebuggerConnection(int port);

// Load a program from a snapshot.
FLETCH_EXPORT FletchProgram FletchLoadSnapshot(unsigned char* snapshot,
                                               int length);

// Load the snapshot from the file and load the program from the snapshot.
FLETCH_EXPORT FletchProgram FletchLoadSnapshotFromFile(const char* path);

// Delete a program.
FLETCH_EXPORT void FletchDeleteProgram(FletchProgram program);

// Load a program from the given location. Location should point to a
// reloacted program heap with appended info block, usually build using
// the flashtool utility or by relocating a loaded program.
FLETCH_EXPORT FletchProgram FletchLoadProgramFromFlash(void* location,
                                                       size_t size);

// Start a process at main, from the program.
FLETCH_EXPORT int FletchRunMain(FletchProgram program);

// Start multiple processes at main, from the programs.
FLETCH_EXPORT void FletchRunMultipleMain(int count,
                                         FletchProgram* programs,
                                         int* exitcodes);

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
FLETCH_EXPORT bool FletchAddDefaultSharedLibrary(const char* library);

// Register a print interception function. When a print occurs the passed
// function will be called with the message, an output id 2 for stdout or output
// id 3 for stderr, as well as the data associated with this registration.
// The result of registration is an interceptor instance that can be used to
// subsequently unregister the interceptor.
FLETCH_EXPORT FletchPrintInterceptor FletchRegisterPrintInterceptor(
    PrintInterceptionFunction function,
    void* data);

// Unregister a print interceptor. This must be called with an interceptor
// instance that was created using the registration function. The interceptor
// instance is reclaimed and no longer valid after having called this function.
FLETCH_EXPORT void FletchUnregisterPrintInterceptor(
    FletchPrintInterceptor interceptor);

#endif  // INCLUDE_FLETCH_API_H_
