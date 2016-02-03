// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_DARTINO_API_H_
#define INCLUDE_DARTINO_API_H_

#include <stdbool.h>

#ifdef _MSC_VER
// TODO(herhut): Do we need a __declspec here for Windows?
#define DARTINO_VISIBILITY_DEFAULT
#else
#define DARTINO_VISIBILITY_DEFAULT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
#define DARTINO_EXPORT extern "C" DARTINO_VISIBILITY_DEFAULT
#else
#define DARTINO_EXPORT DARTINO_VISIBILITY_DEFAULT
#endif

typedef void* DartinoProgram;
typedef void* DartinoPrintInterceptor;
typedef void (*PrintInterceptionFunction)(
    const char* message, int out, void* data);
typedef void (*ProgramExitCallback)(DartinoProgram*, int exitcode, void* data);

// Setup must be called before using any of the other API methods.
DARTINO_EXPORT void DartinoSetup(void);

// TearDown should be called when an application is done using the
// dartino API in order to free up resources.
DARTINO_EXPORT void DartinoTearDown(void);

// Wait for a debugger connection. The debugger will build the program
// to run in the VM and start it.
DARTINO_EXPORT void DartinoWaitForDebuggerConnection(int port);

// Load a program from a snapshot.
DARTINO_EXPORT DartinoProgram DartinoLoadSnapshot(unsigned char* snapshot,
                                               int length);

// Load the snapshot from the file and load the program from the snapshot.
DARTINO_EXPORT DartinoProgram DartinoLoadSnapshotFromFile(const char* path);

// Delete a program.
DARTINO_EXPORT void DartinoDeleteProgram(DartinoProgram program);

// Load a program from the given location. Location should point to a
// reloacted program heap with appended info block, usually build using
// the flashtool utility or by relocating a loaded program.
DARTINO_EXPORT DartinoProgram DartinoLoadProgramFromFlash(void* location,
                                                       size_t size);

// Starts the main method of the program. The given callback will be called once
// all processes of the program have terminated.
//
// The [callback] might be called on DartinoVM internal threads and is not
// allowed to use the Dartino API.
// TODO(kustermann/herhut): We should
//   * make clear what the callback can do and what not (e.g.
//     DartinoDeleteProgram)
//   * use thread-local storage - at least in debug mode - which ensures this.
DARTINO_EXPORT void DartinoStartMain(DartinoProgram program,
                                   ProgramExitCallback callback,
                                   void* callback_data);

// Run the main method of the program and wait until it is done executing.
DARTINO_EXPORT int DartinoRunMain(DartinoProgram program);

// Run the main method of multiple programs and wait until all of them are done
// executing.
DARTINO_EXPORT void DartinoRunMultipleMain(int count,
                                         DartinoProgram* programs,
                                         int* exitcodes);

// Load the snapshot from the file, load the program from the
// snapshot, run the main process of that program and wait until it is done
// executing.
DARTINO_EXPORT void DartinoRunSnapshotFromFile(const char* path);

// Add a default shared library for the dart:ffi foreign lookups.
// More than one default shared library can be added. The libraries
// are used for foreign lookups where no library has been specified.
// The libraries are searched in the order in which they are added.
// The library string must be null-terminated and Dartino does not
// take over ownership of the passed in string.
DARTINO_EXPORT bool DartinoAddDefaultSharedLibrary(const char* library);

// Register a print interception function. When a print occurs the passed
// function will be called with the message, an output id 2 for stdout or output
// id 3 for stderr, as well as the data associated with this registration.
// The result of registration is an interceptor instance that can be used to
// subsequently unregister the interceptor.
DARTINO_EXPORT DartinoPrintInterceptor DartinoRegisterPrintInterceptor(
    PrintInterceptionFunction function,
    void* data);

// Unregister a print interceptor. This must be called with an interceptor
// instance that was created using the registration function. The interceptor
// instance is reclaimed and no longer valid after having called this function.
DARTINO_EXPORT void DartinoUnregisterPrintInterceptor(
    DartinoPrintInterceptor interceptor);

#endif  // INCLUDE_DARTINO_API_H_
