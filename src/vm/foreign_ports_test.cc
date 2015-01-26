// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <unistd.h>
#include <libgen.h>

#include "src/shared/assert.h"
#include "src/shared/connection.h"
#include "src/shared/flags.h"
#include "src/shared/fletch.h"
#include "src/shared/native_process.h"
#include "src/shared/test_case.h"

#include "src/vm/platform.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/session.h"
#include "src/vm/thread.h"

namespace fletch {

static const int kPortReceived = 1;
static const int kReplyReceived = 2;

static Monitor* done_monitor = NULL;
static bool done = false;
static Monitor* phase_monitor = NULL;
static int phase = 0;
static Port* port = NULL;

static void RunDartFile() {
  ConnectionListener listener("127.0.0.1", 0);

  // Prepare the compiler argument.
  char* executable = Flags::executable();
  char* dir = dirname(executable);
  int path_length = strlen(dir) + 33;
  char* compiler = static_cast<char*>(malloc(path_length));
#ifdef GYP
  snprintf(compiler, path_length, "%s/fletchc", dir);
#else
  bool release = strstr(executable, "release") != NULL;
  bool x64 = strstr(executable, "x64") != NULL;
  Platform::OperatingSystem os = Platform::OS();
  snprintf(compiler, path_length, "%s/../../%s_%s_%s/fletchc",
           dir,
           os == Platform::kLinux ? "linux" : "macos",
           release ? "release" : "debug",
           x64 ? "x64" : "x86");
#endif

  // Prepare the dart file argument.
#ifdef GYP
  const char* dart_file = "src/vm/foreign_ports_test.dart";
#else
  const char* dart_file_suffix = "/../../../src/vm/foreign_ports_test.dart";
  path_length = strlen(dir) + strlen(dart_file_suffix) + 1;
  char* dart_file = static_cast<char*>(malloc(path_length));
  snprintf(dart_file, path_length, "%s%s", dir, dart_file_suffix);
#endif

  // Prepare the port argument.
  char port[256];
  snprintf(port, ARRAY_SIZE(port), "--port=%d", listener.Port());
  const char* args[4] = { compiler, dart_file, port, NULL };
  NativeProcess process(compiler, args);
  process.Start();

  Session session(listener.Accept());
  session.Initialize();
  session.StartMessageProcessingThread();
  bool success = session.RunMain();

  EXPECT_EQ(true, success);

  process.Wait();
  free(compiler);
#ifndef GYP
  free(dart_file);
#endif
}

TEST_EXPORT(int PostPortToExternalCode(Port* p) {
  port = p;
  ScopedMonitorLock lock(phase_monitor);
  phase = kPortReceived;
  phase_monitor->NotifyAll();
  return 1;
})

TEST_EXPORT(int PostBackForeign(void* p) {
  EXPECT_EQ(42, *reinterpret_cast<int*>(p));
  ScopedMonitorLock lock(phase_monitor);
  phase = kReplyReceived;
  phase_monitor->NotifyAll();
  return 1;
})

static void Wait(int expected_phase) {
  ScopedMonitorLock lock(phase_monitor);
  while (phase != expected_phase) phase_monitor->Wait();
}

// TODO(ager): We need to have an API for fletch with a DartPort
// abstraction that hides all this internal stuff.
static void PostToPort() {
  port->Lock();
  Process* process = port->process();
  if (process != NULL) {
    int* i = reinterpret_cast<int*>(malloc(sizeof(int)));
    *i = 42;
    bool result = process->EnqueueForeign(port, i, sizeof(*i));
    process->program()->scheduler()->ResumeProcess(process);
    EXPECT_EQ(true, result);
  }
  port->Unlock();
}

static void Done() {
  ScopedMonitorLock lock(done_monitor);
  done = true;
  done_monitor->NotifyAll();
}

static void WaitUntilDone() {
  ScopedMonitorLock lock(done_monitor);
  while (!done) done_monitor->Wait();
}

static void* ExternalThread(void* data) {
  Wait(kPortReceived);
  PostToPort();
  Wait(kReplyReceived);
  Done();
  return NULL;
}

TEST_CASE(NativePort) {
  done_monitor = Platform::CreateMonitor();
  phase_monitor = Platform::CreateMonitor();
  Thread::Run(ExternalThread);
  RunDartFile();
  WaitUntilDone();
}

}  // namespace fletch
