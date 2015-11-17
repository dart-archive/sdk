// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Exit codes recognized by our test infrastructure. This file is shared with
/// our test infrastructure and should be kept simple and only contain
/// int-valued top-level compile-time constants.
library fletchc.driver.exit_codes;

/// Exit code to use when the compiler crashed. This is recognized by our test
/// runner (test.dart) as status `Crash`.
const COMPILER_EXITCODE_CONNECTION_ERROR = 252;

/// Exit code to use when the compiler crashed. This is recognized by our test
/// runner (test.dart) as status `Crash`.
const COMPILER_EXITCODE_CRASH = 253;

/// Exit code to use when the program running on the Fletch VM encounters a
/// compile-time error. This is recognized by our test runner (test.dart) as
/// status `CompileTimeError`.
const DART_VM_EXITCODE_COMPILE_TIME_ERROR = 254;

/// Exit code to use when the program running on the Fletch VM throws an
/// uncaught exception. This is recognized by out test runner (test.dart) as
/// status `RuntimeError`.
const DART_VM_EXITCODE_UNCAUGHT_EXCEPTION = 255;

/// Exit code returned by `compile` verb when `--fatal-incremental-failures` is
/// used and incremental compilation failed.
const INCREMENTAL_COMPILER_FAILED = 3;

/// Exit code returned by `compile` verb when `--analyze-only` is used and
/// problems (other than errors) were detected.
const ANALYSIS_HAD_NON_ERROR_PROBLEMS = 2;

/// Exit code returned by `compile` verb when `--analyze-only` is used and
/// errors were detected.
const ANALYSIS_HAD_ERRORS = 1;
