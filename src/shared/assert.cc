// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"

#include <stdarg.h>
#include <cxxabi.h>
#include <execinfo.h>

#include <cstdlib>

namespace fletch {

void DynamicAssertionHelper::Fail(const char* format, ...) {
  // Print out the error.
  fprintf(stderr, "%s:%d: error: ", file_, line_);
  va_list arguments;
  va_start(arguments, format);
  char buffer[KB];
  vsnprintf(buffer, sizeof(buffer), format, arguments);
  va_end(arguments);
  fprintf(stderr, "%s\n", buffer);

  DumpStacktrace();

  // In case of failed assertions, abort right away. Otherwise, wait
  // until the program is exiting before producing a non-zero exit
  // code through abort.
  if (kind_ == ASSERT) std::abort();
  static bool failed = false;
  if (!failed) std::atexit(std::abort);
  failed = true;
}

// NOTE: This function uses compiler-specific features to retrieve
// the current stacktrace.
void DynamicAssertionHelper::DumpStacktrace() {
  const int kMaxFrames = 200;
  void* buffer[kMaxFrames];

  int number_of_frames = backtrace(buffer, kMaxFrames);
  char** strings = backtrace_symbols(buffer, number_of_frames);
  if (strings != NULL) {
    fprintf(stderr, "\nCurrent stacktrace:\n");
    for (int i = 0; i < number_of_frames; i++) {
      char* string = strings[i];

      // Normally a frame string looks like:
      //    "<binary-name>(<mangled_name>+<hex-offset>)"
      // We try to extract <mangled_name> and demangle it.
      char* open_paren = NULL;
      char* plus = NULL;
      char* close_paren = NULL;
      int pos = 0;
      while (string[pos] != '\0') {
        if (string[pos] == '(') {
          open_paren = &string[pos];
        } else if (string[pos] == '+') {
          plus = &string[pos];
        } else if (string[pos] == ')') {
          close_paren = &string[pos];
        }
        pos++;
      }

      // If we found the markers, we'll try to demangle the name.
      if (open_paren != NULL && plus != NULL && close_paren != NULL) {
        int mangled_name_length = plus - open_paren - 1;
        char* mangled_name =
            static_cast<char*>(malloc(mangled_name_length + 1));
        memcpy(mangled_name, open_paren + 1, mangled_name_length);
        mangled_name[mangled_name_length] = '\0';

        int status;
        char* demangled_string = abi::__cxa_demangle(
            mangled_name, NULL, NULL, &status);
        if (status == 0) {
          *open_paren = '\0';
          fprintf(stderr, "  %s(%s%s\n", string, demangled_string, plus);
        } else {
          fprintf(stderr, "  %s\n", string);
        }
        free(demangled_string);

        free(mangled_name);
      } else {
        fprintf(stderr, "  %s\n", string);
      }
    }
    fprintf(stderr, "\n");
    free(strings);
  } else {
    fprintf(stderr, "\nCould not get a stacktrace.\n");
  }
}


}  // namespace fletch
