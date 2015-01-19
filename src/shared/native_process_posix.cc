// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/native_process.h"

#include <errno.h>
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
  int pid = TEMP_FAILURE_RETRY(fork());
  if (pid < 0) UNREACHABLE();
  if (pid == 0) {
    // Child.
    execvp(executable_, const_cast<char**>(argv_));
    perror("execvp failed");
    UNIMPLEMENTED();
  }
  // Parent
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
