// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef DARTINO_ENABLE_NATIVE_PROCESSES

#if defined(DARTINO_TARGET_OS_WIN)

#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/process.h"
#include "src/shared/assert.h"

namespace dartino {

BEGIN_NATIVE(NativeProcessSpawnDetached) {
  word array = AsForeignWord(arguments[0]);
  if (array == 0) return Failure::illegal_state();
  Object* result = process->NewInteger(-1);
  if (result->IsRetryAfterGCFailure()) return result;
  char** args = reinterpret_cast<char**>(array);
  char* path = args[0];
  if (path == NULL) return Failure::illegal_state();
  int argc = 0;
  char** argp = args;
  int arg_length = 1;
  // args is terminated by a NULL entry. We add 3 additional characters for
  // storing quotes and separating whitespace.
  while (*argp != NULL) {
    arg_length += strlen(*argp++) + 3;
  }
  // Allocate enough space to allow for escaping double quotes.
  char* command_line = new char[arg_length * 2];
  char* pos = command_line;
  for (argp = args; *argp != NULL; ++argp) {
    // Quote the argument
    *(pos++) = '"';
    char* argument = *argp;
    // Special case of empty argument.
    if (*argument == '\0') {
      *(pos++) = '"';
      *(pos++) = ' ';
      continue;
    }
    // Windows argument parsing is interesting. Certain sequences of double
    // quotes escape the quote, so we escape all double quotes using the
    // backslash. However, only '\"' is an escape sequence, '\' by itself
    // does not need escaping. So only escape '\' if it is followed by a
    // double quote or escaped double quote.
    char prev, curr = '"', next = *argument;
    do {
      prev = curr;
      curr = next;
      next = *(++argument);
      if (curr == '"') {
        if (prev == '\\') {
          // We have to escape the previous \, as \" is a special sequence
          // and the otherwise resulting \\" does not what we want.
          *(pos++) = '\\';
        }
        // Escape the double quote.
        *(pos++) = '\\';
      } else if (curr == '\\' && next == '\0') {
        // We have to escape the \, as we will end the string with a
        // double quote.
        *(pos++) = '\\';
      }
      // Write the actual character.
      *(pos++) = curr;
    } while (next != '\0');
    // Terminate the current argument and add some whitespace.
    *(pos++) = '"';
    *(pos++) = ' ';
  }
  // Add null termination. This will overwrite the white space appended for
  // the last argument.
  *(pos-1) = '\0';

  STARTUPINFO startup_info;
  PROCESS_INFORMATION process_info;

  ZeroMemory(&startup_info, sizeof(startup_info));
  startup_info.cb = sizeof(startup_info);

  bool status = CreateProcess(path,
                              command_line,
                              NULL,  // ProcessAttributes
                              NULL,  // ThreadAttributes
                              false,  // InheritHandles
                              CREATE_UNICODE_ENVIRONMENT | DETACHED_PROCESS,
                              NULL,  // EnvironmentBlock
                              NULL,  // SystemWorkingDirectory
                              &startup_info,
                              &process_info);
  delete[] command_line;
  if (!status) {
    // Result has been preallocated with a value of -1;
    return result;
  }
  // TODO(herhut): Consider using WaitForInputIdle here.
  CloseHandle(process_info.hProcess);
  CloseHandle(process_info.hThread);
  LargeInteger::cast(result)->set_value(process_info.dwProcessId);
  return result;
}
END_NATIVE()

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_WIN)

#endif  // !DARTINO_ENABLE_NATIVE_PROCESSES
