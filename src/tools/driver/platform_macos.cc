// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <mach-o/dyld.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/errno.h>

#include "src/shared/assert.h"

#include "src/tools/driver/platform.h"

namespace fletch {

void GetPathOfExecutable(char* path, size_t path_length) {
  uint32_t bytes_copied = path_length;
  if (_NSGetExecutablePath(path, &bytes_copied) != 0) {
    FATAL1("_NSGetExecutablePath failed, %u bytes left.", bytes_copied);
  }
}

static int* signal_pipe = NULL;

static void SignalHandler(int signal) {
  int old_errno = errno;
  if (write(signal_pipe[1], &signal, sizeof(signal)) == -1) {
    const char message[] = "write failed in signal handler\n";
    write(STDERR_FILENO, message, sizeof(message));
    UNREACHABLE();
  }
  errno = old_errno;
}

int SignalFileDescriptor() {
  if (signal_pipe != NULL) {
    FATAL("SignalFileDescriptor() can only be called once.");
  }
  signal_pipe = reinterpret_cast<int*>(calloc(2, sizeof(*signal_pipe)));
  if (signal_pipe == NULL) {
    FATAL1("calloc failed: %s", strerror(errno));
  }
  if (pipe(signal_pipe) == -1) {
    FATAL1("pipe failed: %s", strerror(errno));
  }
  struct sigaction* action =
      reinterpret_cast<struct sigaction*>(calloc(1, sizeof(*action)));
  if (action == NULL) {
    FATAL1("calloc failed: %s", strerror(errno));
  }
  action->sa_handler = SignalHandler;
  sigaction(SIGINT, action, NULL);
  bzero(action, sizeof(*action));
  action->sa_handler = SignalHandler;
  sigaction(SIGTERM, action, NULL);

  return signal_pipe[0];
}

int ReadSignal(int signal_pipe) {
  int signal;
  ssize_t bytes_count =
      TEMP_FAILURE_RETRY(read(signal_pipe, &signal, sizeof(signal)));
  if (bytes_count == 0) {
    FATAL("signal_pipe closed unexpectedly.");
  } else if (bytes_count < 0) {
    FATAL1("Error reading from signal_pipe: %s", strerror(errno));
  }
  return signal;
}

void Exit(int exit_code) {
  if (exit_code < 0) {
    signal(-exit_code, SIG_DFL);
    raise(-exit_code);
  } else {
    exit(exit_code);
  }
  UNREACHABLE();
}

}  // namespace fletch
