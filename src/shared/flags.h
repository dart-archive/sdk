// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_FLAGS_H_
#define SRC_SHARED_FLAGS_H_

#include "src/shared/assert.h"
#include "src/shared/globals.h"

namespace fletch {

// Flags provide access to commmand line flags.
//
// Syntax:
//   -Xname (equivalent to -Xname=true)
//   -Xname=<boolean>|<int>|<address>|<string>
//
// debug means the flag is ONLY available in the debug build.
// release means the flag is available in both the debug and release build.

#define BOOLEAN(macro, name, value, doc) \
  macro(bool, Boolean, name, value, doc)
#define INTEGER(macro, name, value, doc) \
  macro(int, Integer, name, value, doc)
#define CSTRING(macro, name, value, doc) \
  macro(const char*, String, name, value, doc)

#define APPLY_TO_FLAGS(debug, release)                 \
  BOOLEAN(release, expose_gc, false,                   \
      "Expose invoking GC to native call.")            \
  BOOLEAN(debug, validate_stack, false,                \
      "Validate stack at each interperter step")       \
  BOOLEAN(release, unfold_program, false,              \
      "Unfold the program before running")             \
  BOOLEAN(release, gc_on_delete, false,                \
      "GC the heap at when terminating isolate")       \
  BOOLEAN(release, validate_heaps, false,              \
      "Validate consistency of heaps.")                \
  BOOLEAN(release, run_on_foreign_thread, false,       \
      "Allow a foreign thread to run the interpreter") \
  BOOLEAN(debug, log_decoder, false,                   \
      "Log decoding")                                  \
  BOOLEAN(debug, print_program_statistics, false,      \
      "Print statistics about the program")            \
  BOOLEAN(release, print_heap_statistics, false,       \
      "Print heap statistics before GC")               \
  BOOLEAN(release, verbose, false,                     \
      "Verbose output")                                \
  BOOLEAN(debug, print_flags, false,                   \
      "Print flags")                                   \
  BOOLEAN(release, profile, false,                     \
      "Profile the execution of the entire VM")        \
  INTEGER(release, profile_interval, 1000,             \
      "Profile interval in us")                        \
  CSTRING(release, filter, NULL,                       \
      "Filter string for unit testing")                \
  /* Temporary compiler flags */                       \
  BOOLEAN(release, trace_compiler, false, "")          \
  BOOLEAN(release, trace_library, false, "")           \


#ifdef DEBUG
#define DECLARE_DEBUG_FLAG(type, prefix, name, value, doc) \
  static type name;
#else
#define DECLARE_DEBUG_FLAG(type, prefix, name, value, doc) \
  static const type name = value;
#endif

#define DECLARE_RELEASE_FLAG(type, prefix, name, value, doc) \
  static type name;

class Flags {
 public:
  APPLY_TO_FLAGS(DECLARE_DEBUG_FLAG, DECLARE_RELEASE_FLAG)

  // Extract the flag values from the command line arguments.
  static void ExtractFromCommandLine(int* argc, char** argv);

  static char* executable() { return executable_; }

 private:
  static char* executable_;
};

}  // namespace fletch

#endif  // SRC_SHARED_FLAGS_H_
