// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_NATIVE_PROCESSES

#ifdef FLETCH_TARGET_OS_POSIX

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

#include "src/shared/platform.h"
#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

const int MAX_MESSAGE_LENGTH = 256;

static int ClosePipes(int pipes[2]) {
  int err = TEMP_FAILURE_RETRY(close(pipes[0]));
  if (err < 0) {
    int tmp_errno = errno;
    TEMP_FAILURE_RETRY(close(pipes[1]));
    errno = tmp_errno;
    return err;
  }
  return TEMP_FAILURE_RETRY(close(pipes[1]));
}

static int CreatePipes(int pipes[2]) {
  int err = pipe(pipes);
  if (err < 0) {
    return err;
  }
  err = fcntl(pipes[0], F_SETFD, FD_CLOEXEC);
  if (err < 0) {
    int tmp_errno = errno;
    ClosePipes(pipes);
    errno = tmp_errno;
    return err;
  }
  err = fcntl(pipes[1], F_SETFD, FD_CLOEXEC);
  if (err < 0) {
    int tmp_errno = errno;
    ClosePipes(pipes);
    errno = tmp_errno;
  }
  return err;
}

static pid_t Fork() {
  // Flush all streams to ensure no duplicate output after forking.
  int err = TEMP_FAILURE_RETRY(fflush(NULL));
  if (err != 0) {
    return -1;
  }
  return fork();
}

static void SendErrorAndDie(int result_pipe, int error, const char* msg) {
  // We write the negative errno first which allows the parent to determine
  // that a message must follow.
  // Doing an abort will cause core dumps to be written on machine where
  // they are enabled. We only do that if the write to send the error back
  // fails.
  ASSERT(strlen(msg) + 1 <= MAX_MESSAGE_LENGTH);
  if (TEMP_FAILURE_RETRY(write(result_pipe, &error, sizeof(int))) < 0) {
    Platform::ImmediateAbort();
  }
  if (TEMP_FAILURE_RETRY(write(result_pipe, msg, strlen(msg) + 1)) < 0) {
    Platform::ImmediateAbort();
  }
  exit(1);
}

// This method is used to report back errors sent to the parent process via
// the result_pipe. It must only be used in the parent process and only after
// having received a negative error number from the child/grandchild process.
// Also don't call it after having set errno in parent since it will be
// overwritten by the read/close calls in this method.
static void ReportError(int result_pipe) {
  char msg[MAX_MESSAGE_LENGTH];
  int err = TEMP_FAILURE_RETRY(read(result_pipe, msg, sizeof(msg)));
  if (err > 0) {
    Print::Error(msg);
  } else {
    Print::Error("Failed to read error message from child. Errno %d.\n", errno);
  }
  TEMP_FAILURE_RETRY(close(result_pipe));
}

static pid_t WaitForPid(int child_pid, int result_pipe) {
  // Running in parent process (must return an error if failing).

  // Wait for immediate child to exit.
  int status;
  if (TEMP_FAILURE_RETRY(waitpid(child_pid, &status, 0)) < 0) {
    int tmp_errno = errno;
    TEMP_FAILURE_RETRY(close(result_pipe));
    Print::Error(
        "Failed when waiting on immediate child process to exit. "
        "Error: %d",
        errno);
    errno = tmp_errno;
    return -1;
  }
  int err;
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    // Try to see if the child send an errno before dying, if not default to
    // EFAULT in lack of better.
    int error_number;
    err = TEMP_FAILURE_RETRY(read(result_pipe, &error_number, sizeof(int)));
    if (err > 0) {
      // Received an errno from the child process before it exited.
      // In that case it should also have sent an error message. Read that and
      // write it out.
      ReportError(result_pipe);
      errno = -error_number;
    } else {
      TEMP_FAILURE_RETRY(close(result_pipe));
      errno = EFAULT;
    }
    // Ignore if the read or close failed.
    return -1;
  }

  // Wait for the pid of the detached process.
  int grandchild_pid;
  err = TEMP_FAILURE_RETRY(read(result_pipe, &grandchild_pid, sizeof(int)));
  if (err < 0) {
    int tmp_errno = errno;
    TEMP_FAILURE_RETRY(close(result_pipe));
    Print::Error(
        "Failed when reading the pid of the detached process with "
        "error: %d",
        errno);
    errno = tmp_errno;
    return err;
  }
  // If the pid is negative the child or grandchild failed with the negative
  // errno. Propagate the errno to this process and return -1.
  if (grandchild_pid < 0) {
    ReportError(result_pipe);
    errno = -grandchild_pid;
    return -1;
  }
  // Wait for the grandchild to either close the other end of the pipe
  // (execv succeeds) or return an error (negative errno).
  int error_number;
  err = TEMP_FAILURE_RETRY(read(result_pipe, &error_number, sizeof(int)));
  if (err > 0) {
    // Grandchild failed to execv and sent back an error.
    ReportError(result_pipe);
    errno = -error_number;
    return -1;
  } else if (err < 0) {
    // The read call failed for some unknown reason.
    int tmp_errno = errno;
    TEMP_FAILURE_RETRY(close(result_pipe));
    Print::Error(
        "Failed when waiting for detached process with pid to execute "
        "with error: %d",
        tmp_errno);
    errno = tmp_errno;
    return -1;
  }
  TEMP_FAILURE_RETRY(close(result_pipe));
  return static_cast<pid_t>(grandchild_pid);
}

static void RunDetached(char* path, char* arguments[], int result_pipe) {
  // This is running in the immediate child.

  // Check the result_pipe is above the fds will we redirect to /dev/null.
  ASSERT(result_pipe > STDERR_FILENO);

  // Close all open file descriptors, except for the result_pipe.
  int max_fds = sysconf(_SC_OPEN_MAX);
  if (max_fds == -1) max_fds = _POSIX_OPEN_MAX;
  for (int fd = 0; fd < max_fds; fd++) {
    if (fd != result_pipe) {
      TEMP_FAILURE_RETRY(close(fd));
    }
  }

  // Re-open stdin, stdout and stderr and connect them to /dev/null.
  // The loop above should already have closed all of them, so
  // creating new file descriptors should start at STDIN_FILENO.
  int null_fd = TEMP_FAILURE_RETRY(open("/dev/null", O_RDWR));
  if (null_fd != STDIN_FILENO) {
    int tmp_errno = errno;
    char msg[MAX_MESSAGE_LENGTH];
    snprintf(msg, MAX_MESSAGE_LENGTH,
             "Failed opening /dev/null as stdin. Null fd is %d\n", null_fd);
    SendErrorAndDie(result_pipe, -tmp_errno, msg);
  }
  if (TEMP_FAILURE_RETRY(dup2(null_fd, STDOUT_FILENO)) != STDOUT_FILENO) {
    SendErrorAndDie(result_pipe, -errno,
                    "Failed redirector stdout to /dev/null\n");
  }
  if (TEMP_FAILURE_RETRY(dup2(null_fd, STDERR_FILENO)) != STDERR_FILENO) {
    SendErrorAndDie(result_pipe, -errno,
                    "Failed redirector stderr to /dev/null\n");
  }

  // Set new process group id. This makes this process the session leader.
  // However after forking the child is not a leader and hence cannot acquire
  // a controlling terminal, see man setsid and perhaps
  // http://www.linusakesson.net/programming/tty/index.php if you are really
  // interested.
  if (setsid() < 0) {
    SendErrorAndDie(
        result_pipe, -errno,
        "Failed to create new session with new group id when spawning a "
        "detached process\n");
  }

  // Fork again to create a truly detached process.
  pid_t pid = Fork();
  if (pid < 0) {
    SendErrorAndDie(result_pipe, -errno,
                    "Failed to double fork when spawning a detached process\n");
  }
  if (pid > 0) {
    // Exit cleanly to unblock the waiting parent. Use _exit to silence ASAN.
    _exit(0);
  }

  // In grandchild.

  // Send back the pid.
  pid = getpid();
  if (TEMP_FAILURE_RETRY(write(result_pipe, &pid, sizeof(pid_t))) < 0) {
    SendErrorAndDie(
        result_pipe, -errno,
        "Failed to return grandchild pid when spawning a detached process\n");
  }

  // The execv method only returns on error. If it succeeds the result_pipe is
  // closed and the parent will receive an EOF which indicates the execv call
  // succeeded.
  execv(path, arguments);
  char msg[MAX_MESSAGE_LENGTH];
  snprintf(msg, MAX_MESSAGE_LENGTH,
           "Failed to execv a detached process with errno %d\n", errno);
  SendErrorAndDie(result_pipe, -errno, msg);
  UNREACHABLE();
}

BEGIN_NATIVE(NativeProcessSpawnDetached) {
  word array = AsForeignWord(arguments[0]);
  if (array == 0) return Failure::illegal_state();
  char** args = reinterpret_cast<char**>(array);
  char* path = args[0];
  if (path == 0) return Failure::illegal_state();

  int pipes[2];
  int err = CreatePipes(pipes);
  if (err < 0) {
    return process->ToInteger(err);
  }

  // Fork
  pid_t pid = Fork();
  if (pid < 0) {
    ClosePipes(pipes);
    return process->ToInteger(-1);
  }
  if (pid > 0) {
    // In parent, close the child/grandchild's end of the pipe and wait for them
    // to complete.
    err = TEMP_FAILURE_RETRY(close(pipes[1]));
    if (err < 0) {
      TEMP_FAILURE_RETRY(close(pipes[0]));
      return process->ToInteger(err);
    }
    pid = WaitForPid(pid, pipes[0]);
    return process->ToInteger(pid);
  }

  Thread::TeardownOSSignals();

  // In child, fork again and call exec from grandchild, should not return;
  RunDetached(path, args, pipes[1]);

  // We cannot get to here since either we exited due to success or error or
  // got overlayed by execv.
  UNREACHABLE();
  exit(1);  // silence compiler
}
END_NATIVE()

}  // namespace fletch

#endif  // FLETCH_TARGET_OS_POSIX

#endif  // FLETCH_ENABLE_NATIVE_PROCESSES
