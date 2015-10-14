// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_MACOS)

#include <fcntl.h>
#include <mach-o/dyld.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/errno.h>
#include <unistd.h>

#include "src/shared/assert.h"

#include "src/tools/driver/platform.h"

#define MAX_SIGNAL SIGUSR2

namespace fletch {

static int signal_pipe[] = { -1, -1 };

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
  if (signal_pipe[0] != -1) {
    FATAL("SignalFileDescriptor() can only be called once.");
  }
  if (pipe(signal_pipe) == -1) {
    FATAL1("pipe failed: %s", strerror(errno));
  }
  if (fcntl(signal_pipe[0], F_SETFD, FD_CLOEXEC) == -1) {
    FATAL1("fcntl failed: %s", strerror(errno));
  }
  if (fcntl(signal_pipe[1], F_SETFD, FD_CLOEXEC) == -1) {
    FATAL1("fcntl failed: %s", strerror(errno));
  }
  struct sigaction* action =
      reinterpret_cast<struct sigaction*>(calloc(1, sizeof(*action)));
  if (action == NULL) {
    FATAL1("calloc failed: %s", strerror(errno));
  }
  for (int signal_number = 1; signal_number <= MAX_SIGNAL; signal_number++) {
    if (signal_number == SIGKILL || signal_number == SIGSTOP) {
      // These signals cannot be intercepted.
      continue;
    }
    if (signal_number == SIGTSTP) {
      // Let Ctrl-Z suspend the client.
      continue;
    }
    bzero(action, sizeof(*action));
    action->sa_handler = SignalHandler;
    if (sigaction(signal_number, action, NULL) == -1) {
      FATAL1("sigaction failed: %s", strerror(errno));
    }
  }

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
    // A negative exit code is how dart:io encodes that the process was
    // signalled. To pass this information on to the caller of this process, we
    // cannot use "exit" as it truncates its argument. See WEXITSTATUS and
    // WTERMSIG in wait(2). So to forward the signalled exit status to our
    // parent process, we send a signal to ourselves.
    signal(-exit_code, SIG_DFL);
    raise(-exit_code);
  } else {
    exit(exit_code);
  }
  UNREACHABLE();
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_MACOS)
