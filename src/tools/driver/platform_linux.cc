// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LINUX)

#include <string.h>
#include <unistd.h>
#include <sys/signalfd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#include <stdlib.h>

#include "src/shared/assert.h"

#include "src/tools/driver/platform.h"

namespace fletch {

int SignalFileDescriptor() {
  // Temporarily limit signals to a short list of white-listed signals.
  const bool limit_signals = true;

  sigset_t signal_mask;
  if (sigfillset(&signal_mask) == -1) {
    FATAL1("sigfillset failed: %s", strerror(errno));
  }

  // It isn't possible to block SIGKILL or SIGSTOP, so let's remove them for
  // consistency:
  if (sigdelset(&signal_mask, SIGKILL) == -1) {
    FATAL1("sigdelset(SIGKILL) failed: %s", strerror(errno));
  }
  if (sigdelset(&signal_mask, SIGSTOP) == -1) {
    FATAL1("sigdelset(SIGSTOP) failed: %s", strerror(errno));
  }

  // Since we can't block SIGSTOP, we shouldn't block SIGCONT.
  if (sigdelset(&signal_mask, SIGCONT) == -1) {
    FATAL1("sigdelset(SIGCONT) failed: %s", strerror(errno));
  }

  // Let Ctrl-Z suspend the client.
  if (sigdelset(&signal_mask, SIGTSTP) == -1) {
    FATAL1("sigdelset(SIGTSTP) failed: %s", strerror(errno));
  }

  if (limit_signals) {
    if (sigemptyset(&signal_mask) == -1) {
      FATAL1("sigemptyset failed: %s", strerror(errno));
    }
    // Default signal when running `kill` without specifying a signal.
    if (sigaddset(&signal_mask, SIGTERM) == -1) {
      FATAL1("sigaddset(SIGTERM) failed: %s", strerror(errno));
    }
    // Signal from Ctrl-C.
    if (sigaddset(&signal_mask, SIGINT) == -1) {
      FATAL1("sigaddset(SIGINT) failed: %s", strerror(errno));
    }
    // Signal from Ctrl-\.
    if (sigaddset(&signal_mask, SIGQUIT) == -1) {
      FATAL1("sigaddset(SIGQUIT) failed: %s", strerror(errno));
    }
  }

  if (sigprocmask(SIG_BLOCK, &signal_mask, NULL) == -1) {
    FATAL1("sigprocmask failed: %s", strerror(errno));
  }

  int fd = signalfd(-1, &signal_mask, SFD_CLOEXEC);
  if (fd == -1) {
    FATAL1("signalfd failed: %s", strerror(errno));
  }
  return fd;
}

int ReadSignal(int signal_pipe) {
  struct signalfd_siginfo signal_info;
  ssize_t bytes_read =
      TEMP_FAILURE_RETRY(read(signal_pipe, &signal_info, sizeof(signal_info)));
  if (bytes_read == -1) {
    FATAL1("read failed: %s", strerror(errno));
  }
  if (bytes_read == 0) {
    FATAL("Unexpected EOF in signal_pipe.");
  }
  return signal_info.ssi_signo;
}

void Exit(int exit_code) {
  if (exit_code < 0) {
    sigset_t signal_mask;
    sigemptyset(&signal_mask);
    sigaddset(&signal_mask, -exit_code);
    if (sigprocmask(SIG_UNBLOCK, &signal_mask, NULL) == -1) {
      FATAL1("sigprocmask failed: %s", strerror(errno));
    }
    raise(-exit_code);
  } else {
    exit(exit_code);
  }
  UNREACHABLE();
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LINUX)
