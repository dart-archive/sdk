// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_NATIVE_PROCESSES

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

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
  TEMP_FAILURE_RETRY(write(result_pipe, &error, sizeof(int)));
  FATAL(msg);
}

static pid_t WaitForPid(int child_pid, int result_pipe) {
  // Running in parent process (must return an error if failing).

  // Wait for immediate child to exit.
  int status;
  if (TEMP_FAILURE_RETRY(waitpid(child_pid, &status, 0)) < 0) {
    int tmp_errno = errno;
    TEMP_FAILURE_RETRY(close(result_pipe));
    errno = tmp_errno;
    return -1;
  }
  int err;
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    // Try to see if the child send an errno before dying, if not default to
    // EFAULT in lack of better.
    int error_number;
    err = TEMP_FAILURE_RETRY(
        read(result_pipe, &error_number, sizeof(int)));
    TEMP_FAILURE_RETRY(close(result_pipe));
    errno = err > 0 ? -error_number : EFAULT;
    // Ignore if the read or close failed.
    return -1;
  }

  // Wait for the pid of the detached process.
  int grandchild_pid;
  err =
      TEMP_FAILURE_RETRY(read(result_pipe, &grandchild_pid, sizeof(int)));
  if (err < 0) {
    int tmp_errno = errno;
    TEMP_FAILURE_RETRY(close(result_pipe));
    errno = tmp_errno;
    return err;
  }
  // If the pid is negative the child or grandchild failed with the negative
  // errno. Propage the errno to this process and return -1.
  if (grandchild_pid < 0) {
    errno = -grandchild_pid;
    return -1;
  }
  // Wait for the grandchild to either close the other end of the pipe
  // (execv succeeds) or return an error (negative errno).
  int error_number;
  err = TEMP_FAILURE_RETRY(read(result_pipe, &error_number, sizeof(int)));
  if (err != 0) {
    TEMP_FAILURE_RETRY(close(result_pipe));
    // Propagate the errno if it was sent from the grandchild.
    if (err > 0) errno = -error_number;
    return -1;
  }
  err = TEMP_FAILURE_RETRY(close(result_pipe));
  if (err < 0) {
    return -1;
  }
  return static_cast<pid_t>(grandchild_pid);
}

static void RunDetached(char* path, char* arguments[], int result_pipe) {
  // This is running in the immediate child.

  // Set new process group id. This makes this process the session leader.
  // However after forking the child is not a leader and hence cannot acquire
  // a controlling terminal, see man setsid and perhaps
  // http://www.linusakesson.net/programming/tty/index.php if you are really
  // interested.
  if (setsid() < 0) {
    SendErrorAndDie(result_pipe, -errno,
        "Failed to create new session with new group id when spawning a "
        "detached process");
  }

  // Fork again to create a truly detached process.
  pid_t pid = Fork();
  if (pid < 0) {
    SendErrorAndDie(result_pipe, -errno,
        "Failed to double fork when spawning a detached process");
  }
  if (pid > 0) {
    // Exit cleanly to unblock the waiting parent.
    exit(0);
  }

  // In grandchild.

  // Send back the pid.
  pid = getpid();
  if (TEMP_FAILURE_RETRY(write(result_pipe, &pid, sizeof(pid_t))) < 0) {
    SendErrorAndDie(result_pipe, -errno,
        "Failed to return grandchild pid when spawning a detached process");
  }
  // Redirecting stdin, stdout, and stderr to /dev/null. The spawned process
  // is free to reopen stdout/stderr to something useful.
  int null_fd = TEMP_FAILURE_RETRY(open("/dev/null", O_RDWR));
  if (null_fd < 0) {
    SendErrorAndDie(result_pipe, -errno,
        "Failed to open 'dev/null' when spawning a detached process");
  }
  if (TEMP_FAILURE_RETRY(dup2(null_fd, STDIN_FILENO)) < 0) {
    SendErrorAndDie(result_pipe, -errno,
        "Failed to redirect stdin to  'dev/null' when spawning a detached "
        "process");
  }
  if (TEMP_FAILURE_RETRY(dup2(null_fd, STDOUT_FILENO)) < 0) {
    SendErrorAndDie(result_pipe, -errno,
        "Failed to redirect stdout to  'dev/null' when spawning a detached "
        "process");
  }
  if (TEMP_FAILURE_RETRY(dup2(null_fd, STDERR_FILENO)) < 0) {
    SendErrorAndDie(result_pipe, -errno,
        "Failed to redirect stderr to  'dev/null' when spawning a detached "
        "process");
  }
  if (TEMP_FAILURE_RETRY(close(null_fd)) < 0) {
    SendErrorAndDie(result_pipe, -errno,
        "Failed to close the 'dev/null' fd when spawning a detached process");
  }

  // The execv method only returns on error. If it succeeds the result_pipe is
  // closed and the parent will receive an EOF which indicates the execv call
  // succeeded.
  execv(path, arguments);
  SendErrorAndDie(result_pipe, -errno, "Failed to execv a detached process");
  UNREACHABLE();
}

NATIVE(NativeProcessSpawnDetached) {
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

  // In child, fork again and call exec from grandchild, should not return;
  RunDetached(path, args, pipes[1]);

  // We cannot get to here since either we exited due to success or error or
  // got overlayed by execv.
  UNREACHABLE();
  exit(1);  // silence compiler
}

}  // namespace fletch

#endif  // FLETCH_ENABLE_NATIVE_PROCESSES
