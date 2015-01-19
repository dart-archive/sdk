// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_FLAGS_H_
#define SRC_SHARED_FLAGS_H_

#include "src/shared/assert.h"
#include "src/shared/globals.h"

namespace fletch {

// Flags provides access to commmand line flags.
//
// Syntax:
//   -Xname
//   -Xname=<boolean>|<int>|<address>|<string>
//

class Flags {
 public:
  // Returns true if -X<name> or -X<name>=true.
  inline static bool IsOn(const char* name);

  // Returns value for a provided flag.
  inline static bool IsBool(const char* name, bool* value);
  inline static bool IsInt(const char* name, int* value);
  inline static bool IsAddress(const char* name, uword* value);
  inline static bool IsString(const char* name, char** value);

  // Extract the flag values from the command line arguments.
  static void ExtractFromCommandLine(int* argc, char** argv);

  static char* executable() { return executable_; }

 private:
  static char* executable_;

#ifdef DEBUG
  // Slow version for debug build.
  static bool SlowIsOn(const char* name);
  static bool SlowIsBool(const char* name, bool* value);
  static bool SlowIsInt(const char* name, int* value);
  static bool SlowIsAddress(const char* name, uword* value);
  static bool SlowIsString(const char* name, char** value);
#endif
};

inline bool Flags::IsOn(const char* name) {
#ifdef DEBUG
  return SlowIsOn(name);
#else
  return false;
#endif
}

inline bool Flags::IsBool(const char* name, bool* value) {
#ifdef DEBUG
  return SlowIsBool(name, value);
#else
  return false;
#endif
}

inline bool Flags::IsInt(const char* name, int* value) {
#ifdef DEBUG
  return SlowIsInt(name, value);
#else
  return false;
#endif
}

inline bool Flags::IsAddress(const char* name, uword* value) {
#ifdef DEBUG
  return SlowIsAddress(name, value);
#else
  return false;
#endif
}

inline bool Flags::IsString(const char* name, char** value) {
#ifdef DEBUG
  return SlowIsString(name, value);
#else
  return false;
#endif
}

}  // namespace fletch

#endif  // SRC_SHARED_FLAGS_H_
