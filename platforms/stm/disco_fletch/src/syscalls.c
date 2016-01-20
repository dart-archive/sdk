// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Support file for GNU libc. Most of this is noops or always
// returning an error. The read and write functions can be hooked into
// through weak functions. `gettimeofday` is implemented in terms of cmsis_os
// osKernelSysTick.

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <sys/times.h>
#include <errno.h>
#include <sys/wait.h>

#include <cmsis_os.h>

#define MAX_STACK_SIZE 0x2000

// Weak symbols for hooking into the read/write.
extern int __io_putchar(int ch) __attribute__((weak));
extern int __io_getchar(void) __attribute__((weak));

void* _sbrk(int incr) {
  // We don't use the newlib C-heap implementation (which use _sbrk to
  // get system memory). The cmpctmalloc C-heap implementation we use
  // does not use _sbrk (uses the page allocator) to get system memory.
  // So we don't expect any calls to _sbrk at the moment.
  UNREACHABLE();
}

int _gettimeofday (struct timeval * tp, struct timezone * tzp) {
  uint64_t microseconds =
      ((uint64_t)osKernelSysTick()) * osKernelSysTickFrequency;
  tp->tv_sec = microseconds / 1000000;
  tp->tv_usec = microseconds % 1000000;
  if (tzp) {
    tzp->tz_minuteswest = 0;
    tzp->tz_dsttime = 0;
  }
  return 0;
}

int _getpid(void) {
  return 1;
}

int _kill(int pid, int sig) {
  errno = EINVAL;
  return -1;
}

void _exit (int status) {
  _kill(status, -1);
  while (1) {}
}

int _write(int file, char *ptr, int len) {
  for (int i = 0; i < len; i++) {
    __io_putchar( *ptr++ );
  }
  return len;
}

int _close(int file) {
  return -1;
}

int _fstat(int file, struct stat *st) {
  st->st_mode = S_IFCHR;
  return 0;
}

int _isatty(int file) {
  return 1;
}

int _lseek(int file, int ptr, int dir) {
  return 0;
}

int _read(int file, char *ptr, int len) {
  for (int i = 0; i < len; i++) {
    *ptr++ = __io_getchar();
  }
  return len;
}

int _open(char *path, int flags, ...) {
  return -1;
}

int _wait(int *status) {
  errno = ECHILD;
  return -1;
}

int _unlink(char *name) {
  errno = ENOENT;
  return -1;
}

int _times(struct tms *buf) {
  return -1;
}

int _stat(char *file, struct stat *st) {
  st->st_mode = S_IFCHR;
  return 0;
}

int _link(char *old, char *new) {
  errno = EMLINK;
  return -1;
}

int _fork(void) {
  errno = EAGAIN;
  return -1;
}

int _execve(char *name, char **argv, char **env) {
  errno = ENOMEM;
  return -1;
}
