// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/flags.h"
#include "src/shared/test_case.h"
#include "src/shared/platform.h"

#include "include/dartino_api.h"

namespace dartino {

// This multiprogram runner uses only the DartinoStartMain() API function.
class Runner {
 public:
  Runner(int count, DartinoProgram* programs, int* exitcodes, bool freeze)
      : monitor_(Platform::CreateMonitor()),
        programs_(programs),
        exitcodes_(exitcodes),
        count_(count),
        started_(0),
        awaited_(0),
        finished_(0),
        freeze_(freeze) {
    freeze_group_ = DartinoCreateProgramGroup("odd-numbered-programs");
  }

  ~Runner() {
    DartinoDeleteProgramGroup(freeze_group_);
    delete monitor_;
  }

  // Starts all programs and then waits for all of them.
  void RunInParallel() { RunInBatches(count_); }

  // Starts one program, waits for it to complete and repeat until no more
  // programs need to be run.
  void RunInSequence() { RunInBatches(1); }

  // Starts [batch_size] programs, waits for them to complete and reapeat
  // until no more programs need to be run.
  void RunInBatches(int batch_size) {
    ASSERT((count_ % batch_size) == 0);
    ASSERT(count_ == batch_size || (batch_size % 2) == 0 || !freeze_);

    int normal = batch_size / 2;
    int frozen = batch_size - normal;

    int batches = count_ / batch_size;
    for (int batch_nr = 1; batch_nr <= batches; batch_nr++) {
      if (freeze_) {
        Start(batch_size);

        // Freeze odd numbered programs & wait for even numbered programs.
        Freeze();
        Wait(normal);

        // Unfreeze odd numbered programs & wait for for them.
        Unfreeze();
        Wait(frozen);
      } else {
        Start(batch_size);
        Wait(batch_size);
      }
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
  DartinoProgram* programs_;
  DartinoProgramGroup freeze_group_;
  int* exitcodes_;
  int count_;
  int started_;
  int awaited_;
  int finished_;
  bool freeze_;

  static void CaptureExitCode(DartinoProgram program,
                              int exitcode,
                              void* data) {
    Runner* runner = reinterpret_cast<Runner*>(data);
    ScopedMonitorLock locker(runner->monitor_);
    for (int i = 0; i < runner->count_; i++) {
      if (runner->programs_[i] == program) {
        runner->exitcodes_[i] = exitcode;
        runner->finished_++;
        runner->monitor_->NotifyAll();

        DartinoDeleteProgram(program);

        return;
      }
    }
    UNREACHABLE();
  }

  void Start(int count) {
    ScopedMonitorLock locker(monitor_);
    for (int i = started_; i < started_ + count; i++) {
      DartinoProgram program = programs_[i];
      DartinoStartMain(program, &Runner::CaptureExitCode, this, 0, NULL);
      if ((i % 2) == 1) {
        DartinoAddProgramToGroup(freeze_group_, program);
      }
    }
    started_ += count;
  }

  void Freeze() {
    DartinoFreezeProgramGroup(freeze_group_);
  }

  void Unfreeze() {
    DartinoUnfreezeProgramGroup(freeze_group_);
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

static void PrintAndDie(char* program, char **argv) {
  FATAL1("Usage: %s "
         "[--freeze-odd] "
         "<parallel|sequence|batch=NUM|overlapped=NUM> "
         "[[<snapshot> <expected-exitcode>] ...]",
         argv[0]);
}

// Whether to freeze odd-numbered programs.
static bool test_flag_freeze = false;

static void ExtractTestFlags(int* argc, char*** argv) {
  while (*argc > 0) {
    if (strcmp((*argv)[0], "--freeze-odd") == 0) {
      test_flag_freeze = true;
      --(*argc);
      ++(*argv);
    } else {
      break;
    }
  }
}

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);

  DartinoSetup();

  char* program = argv[0];
  --argc; ++argv;

  ExtractTestFlags(&argc, &argv);

  if (argc <= 1 || (argc % 2) != 1) PrintAndDie(program, argv);

  bool parallel = strcmp(argv[0], "parallel") == 0;
  bool sequence = strcmp(argv[0], "sequence") == 0;
  bool batch = strncmp(argv[0], "batch=", strlen("batch=")) == 0;
  bool overlapped = strncmp(argv[0], "overlapped=", strlen("overlapped=")) == 0;
  if (!parallel && !sequence && !batch && !overlapped) {
    PrintAndDie(program, argv);
  }

  int program_count = (argc - 1) / 2;
  DartinoProgram* programs = new DartinoProgram[program_count];
  int* expected_exit_codes = new int[program_count];
  for (int i = 0; i < program_count; i++) {
    List<uint8> bytes = Platform::LoadFile(argv[1 + 2 * i]);
    if (bytes.is_empty()) FATAL("Invalid snapshot");
    programs[i] = DartinoLoadSnapshot(bytes.data(), bytes.length());
    expected_exit_codes[i] = atoi(argv[1 + 2 * i + 1]);
    bytes.Delete();
  }

  int result = 0;
  {
    int* actual_exitcodes = new int[program_count];
    Runner runner(program_count, programs, actual_exitcodes, test_flag_freeze);
    if (parallel) {
      runner.RunInParallel();
    } else if (sequence) {
      runner.RunInSequence();
    } else if (batch) {
      int batch_size = atoi(argv[0] + strlen("batch="));
      runner.RunInBatches(batch_size);
    } else if (overlapped) {
      int overlapped = atoi(argv[0] + strlen("overlapped="));
      runner.RunOverlapped(overlapped);
    } else {
      UNREACHABLE();
    }

    for (int i = 0; i < program_count; i++) {
      if (expected_exit_codes[i] != actual_exitcodes[i]) {
        fprintf(stderr, "%s: Expected exitcode: %d, Actual exitcode: %d\n",
            argv[1 + 2 * i], expected_exit_codes[i], actual_exitcodes[i]);
        result++;
      }
    }

    delete[] actual_exitcodes;
    delete[] expected_exit_codes;
    delete[] programs;
  }

  DartinoTearDown();

  return result;
}

}  // namespace dartino

int main(int argc, char** argv) { return dartino::Main(argc, argv); }
