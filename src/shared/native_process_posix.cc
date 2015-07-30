// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#include "src/shared/native_process.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

#include "src/shared/assert.h"

namespace fletch {

struct NativeProcess::ProcessData {
  int pid;
};

NativeProcess::NativeProcess(const char* executable, const char** argv)
    : data_(new ProcessData()),
      executable_(executable),
      argv_(argv) {
  data_->pid = -1;
}

NativeProcess::~NativeProcess() {
  if (data_->pid != -1) {
    int status = TEMP_FAILURE_RETRY(kill(data_->pid, SIGTERM));
    ASSERT(status == 0);
  }
  delete data_;
}

int NativeProcess::Start() {
  int fds[2];
  if (TEMP_FAILURE_RETRY(pipe(fds)) == -1) UNREACHABLE();
  int pid = TEMP_FAILURE_RETRY(fork());
  if (pid < 0) UNREACHABLE();
  if (pid == 0) {
    TEMP_FAILURE_RETRY(close(fds[0]));
    if (TEMP_FAILURE_RETRY(fcntl(fds[1], F_SETFD, O_CLOEXEC)) == -1) {
      UNREACHABLE();
    }
    // Child.
    execvp(executable_, const_cast<char**>(argv_));
    uint8 value = 1;
    TEMP_FAILURE_RETRY(write(fds[1], &value, sizeof(value)));
    perror("execvp failed");
    UNIMPLEMENTED();
  }
  // Parent
  TEMP_FAILURE_RETRY(close(fds[1]));
  uint8 value = 0;
  int size = TEMP_FAILURE_RETRY(read(fds[0], &value, sizeof(value)));
  if (size != 0) {
    perror("execvp failed");
    UNIMPLEMENTED();
  }
  TEMP_FAILURE_RETRY(close(fds[0]));
  data_->pid = pid;
  return pid;
}

int NativeProcess::Wait() {
  int status;
  ASSERT(data_->pid != -1);
  int pid = TEMP_FAILURE_RETRY(waitpid(data_->pid, &status, 0));
  ASSERT(pid != -1 && pid == data_->pid);
  // Set data_->pid so that we do not accidentally kill another
  // process in the destructor.
  data_->pid = -1;
  return WEXITSTATUS(status);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_POSIX)
