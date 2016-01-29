// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/flags.h"
#include "src/shared/test_case.h"
#include "src/shared/platform.h"

#include "include/fletch_api.h"

namespace fletch {

// This multiprogram runner uses only the FletchStartMain() API function.
class Runner {
 public:
  Runner(int count, FletchProgram* programs, int* exitcodes)
      : monitor_(Platform::CreateMonitor()),
        programs_(programs),
        exitcodes_(exitcodes),
        count_(count),
        started_(0),
        awaited_(0),
        finished_(0) {}
  ~Runner() { delete monitor_; }

  // Starts all programs and then waits for all of them.
  void RunInParallel() { RunInBatches(count_); }

  // Starts one program, waits for it to complete and repeat until no more
  // programs need to be run.
  void RunInSequence() { RunInBatches(1); }

  // Starts [batch_size] programs, waits for them to complete and reapeat
  // until no more programs need to be run.
  void RunInBatches(int batch_size) {
    ASSERT((count_ % batch_size) == 0);

    int batches = count_ / batch_size;
    for (int batch_nr = 1; batch_nr <= batches; batch_nr++) {
      Start(batch_size);
      Wait(batch_size);
    }
  }

  // Starts [max_parallel] programs. As soon as one program finishes a new one
  // will be started.
  void RunOverlapped(int max_parallel) {
    if (count_ < max_parallel) max_parallel = count_;

    Start(max_parallel);
    int remaining = count_ - max_parallel;
    for (int i = 0; i < remaining; i++) {
      Wait(1);
      Start(1);
    }
    Wait(max_parallel);
  }

 private:
  Monitor* monitor_;
  FletchProgram* programs_;
  int* exitcodes_;
  int count_;
  int started_;
  int awaited_;
  int finished_;

  static void CaptureExitCode(FletchProgram* program,
                              int exitcode,
                              void* data) {
    Runner* runner = reinterpret_cast<Runner*>(data);
    ScopedMonitorLock locker(runner->monitor_);
    for (int i = 0; i < runner->count_; i++) {
      if (runner->programs_[i] == program) {
        runner->exitcodes_[i] = exitcode;
        runner->finished_++;
        runner->monitor_->NotifyAll();

        FletchDeleteProgram(program);

        return;
      }
    }
    UNREACHABLE();
  }

  void Start(int count) {
    ScopedMonitorLock locker(monitor_);
    for (int i = started_; i < started_ + count; i++) {
      FletchStartMain(programs_[i], &Runner::CaptureExitCode, this);
    }
    started_ += count;
  }

  void Wait(int count) {
    ScopedMonitorLock locker(monitor_);
    int finished = awaited_ + count;
    while (finished_ < finished) {
      monitor_->Wait();
    }
    awaited_ += count;
  }
};

static void PrintAndDie(char **argv) {
  FATAL1("Usage: %0 "
         "<parallel|sequence|batch=NUM|overlapped=NUM> "
         "[[<snapshot> <expected-exitcode>] ...]",
         argv[0]);
}

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);

  FletchSetup();

  if (argc <= 1 || (argc % 2) != 0) PrintAndDie(argv);

  bool parallel = strcmp(argv[1], "parallel") == 0;
  bool sequence = strcmp(argv[1], "sequence") == 0;
  bool batch = strncmp(argv[1], "batch=", strlen("batch=")) == 0;
  bool overlapped = strncmp(argv[1], "overlapped=", strlen("overlapped=")) == 0;
  if (!parallel && !sequence && !batch && !overlapped) PrintAndDie(argv);

  int program_count = (argc - 2) / 2;
  FletchProgram* programs = new FletchProgram[program_count];
  int* expected_exit_codes = new int[program_count];
  for (int i = 0; i < program_count; i++) {
    List<uint8> bytes = Platform::LoadFile(argv[2 + 2 * i]);
    if (bytes.is_empty()) FATAL("Invalid snapshot");
    programs[i] = FletchLoadSnapshot(bytes.data(), bytes.length());
    expected_exit_codes[i] = atoi(argv[2 + 2 * i + 1]);
    bytes.Delete();
  }

  int* actual_exitcodes = new int[program_count];
  Runner runner(program_count, programs, actual_exitcodes);
  if (parallel) {
    runner.RunInParallel();
  } else if (sequence) {
    runner.RunInSequence();
  } else if (batch) {
    int batch_size = atoi(argv[1] + strlen("batch="));
    runner.RunInBatches(batch_size);
  } else if (overlapped) {
    int overlapped = atoi(argv[1] + strlen("overlapped="));
    runner.RunOverlapped(overlapped);
  } else {
    UNREACHABLE();
  }

  int result = 0;
  for (int i = 0; i < program_count; i++) {
    if (expected_exit_codes[i] != actual_exitcodes[i]) {
      fprintf(stderr, "%s: Expected exitcode: %d, Actual exitcode: %d\n",
          argv[2 + 2 * i], expected_exit_codes[i], actual_exitcodes[i]);
      result++;
    }
  }

  delete[] actual_exitcodes;
  delete[] expected_exit_codes;
  delete[] programs;

  FletchTearDown();

  return result;
}

}  // namespace fletch

int main(int argc, char** argv) { return fletch::Main(argc, argv); }
