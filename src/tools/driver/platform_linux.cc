// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

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
  sigset_t signal_mask;
  sigfillset(&signal_mask);

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
