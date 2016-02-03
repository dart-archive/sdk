// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/flags.h"

#include <string.h>
#include <stdio.h>

#include "src/shared/utils.h"
#include "src/shared/platform.h"

namespace dartino {

#ifdef DEBUG
#define MATERIALIZE_DEBUG_FLAG(type, prefix, name, value, doc) \
  type Flags::name = value;
#else
#define MATERIALIZE_DEBUG_FLAG(type, prefix, name, value, doc)
#endif

#define MATERIALIZE_RELEASE_FLAG(type, prefix, name, value, doc) \
  type Flags::name = value;

APPLY_TO_FLAGS(MATERIALIZE_DEBUG_FLAG, MATERIALIZE_RELEASE_FLAG)

char* Flags::executable_ = NULL;

// Tells whether the given string is a valid flag argument.
static bool IsValidFlag(const char* argument) {
  return (strncmp(argument, "-X", 2) == 0) && (strlen(argument) > 2);
}

static void PrintFlagBoolean(const char* name, bool value, bool init,
                             const char* doc) {
  Print::Out(" - bool %s = %s\n", name, value ? "true" : "false");
}

static void PrintFlagInteger(const char* name, int value, int init,
                             const char* doc) {
  Print::Out(" - int %s = %d\n", name, value);
}

static void PrintFlagString(const char* name, const char* value,
                            const char* init, const char* doc) {
  Print::Out(" - char* %s = \"%s\"\n", name, value);
}

#define XSTR(n) #n

#ifdef DEBUG
#define PRINT_DEBUG_FLAG(type, prefix, name, value, doc) \
  PrintFlag##prefix(XSTR(name), Flags::name, value, doc);
#else
#define PRINT_DEBUG_FLAG(type, prefix, name, value, doc) /* Do nothing. */
#endif

#define PRINT_RELEASE_FLAG(type, prefix, name, value, doc) \
  PrintFlag##prefix(XSTR(name), Flags::name, value, doc);

static void PrintFlags() {
  Print::Out("List of command line flags:\n");

  APPLY_TO_FLAGS(PRINT_DEBUG_FLAG, PRINT_RELEASE_FLAG);

  // Terminate the process with error code.
  Platform::Exit(-1);
}

static bool FlagMatches(const char* a, const char* b) {
  for (; *b != '\0'; a++, b++) {
    if ((*a != *b) && ((*a != '-') || (*b != '_'))) return false;
  }
  return (*a == '\0') || (*a == '=');
}

static bool ProcessFlagBoolean(const char* name_ptr, const char* value_ptr,
                               const char* name, bool* field) {
  // -Xname
  if (value_ptr == NULL) {
    if (FlagMatches(name_ptr, name)) {
      *field = true;
      return true;
    }
    return false;
  }
  // -Xname=<boolean>
  if (FlagMatches(name_ptr, name)) {
    if (strcmp(value_ptr, "false") == 0) {
      *field = false;
      return true;
    }
    if (strcmp(value_ptr, "true") == 0) {
      *field = true;
      return true;
    }
  }
  return false;
}

static bool ProcessFlagInteger(const char* name_ptr, const char* value_ptr,
                               const char* name, int* field) {
  // -Xname=<int>
  if (FlagMatches(name_ptr, name)) {
    char* end;
    int value = strtol(value_ptr, &end, 10);  // NOLINT
    if (*end == '\0') {
      *field = value;
      return true;
    }
  }
  return false;
}

static bool ProcessFlagString(const char* name_ptr, const char* value_ptr,
                              const char* name, const char** field) {
  // -Xname=<string>
  if (FlagMatches(name_ptr, name)) {
    *field = value_ptr;
    return true;
  }
  return false;
}

#ifdef DEBUG
#define PROCESS_DEBUG_FLAG(type, prefix, name, value, doc)                \
  if (ProcessFlag##prefix(name_ptr, value_ptr, XSTR(name), &Flags::name)) \
    return;
#else
#define PROCESS_DEBUG_FLAG(type, prefix, name, value, doc) /* Do nothing */
#endif

#define PROCESS_RELEASE_FLAG(type, prefix, name, value, doc)              \
  if (ProcessFlag##prefix(name_ptr, value_ptr, XSTR(name), &Flags::name)) \
    return;

static void ProcessArgument(const char* argument) {
  ASSERT(IsValidFlag(argument));
  const char* name_ptr = argument + 2;             // skip "-X"
  const char* equals_ptr = strchr(name_ptr, '=');  // Locate '='
  const char* value_ptr = equals_ptr != NULL ? equals_ptr + 1 : NULL;

  APPLY_TO_FLAGS(PROCESS_DEBUG_FLAG, PROCESS_RELEASE_FLAG);
  Print::Out("Failed to recognize flag argument: %s\n", argument);
  // Terminate the process with error code.
  Platform::Exit(-1);
}

void Flags::ExtractFromCommandLine(int* argc, char** argv) {
  // Set the executable name.
  executable_ = argv[0];
  // Compute number of provided flag arguments.
  int number_of_flags = 0;
  for (int index = 1; index < *argc; index++) {
    if (IsValidFlag(argv[index])) number_of_flags++;
  }
  if (number_of_flags == 0) return;

  // Process the the individual flags and shrink argc and argv.
  int count = 1;
  for (int index = 1; index < *argc; index++) {
    if (IsValidFlag(argv[index])) {
      ProcessArgument(argv[index]);
    } else {
      argv[count++] = argv[index];
    }
  }
  *argc = count;

  if (Flags::print_flags) {
    PrintFlags();
    // Process is terminated and will not return.
  }
}

}  // namespace dartino
