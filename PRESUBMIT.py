# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

import cpplint

"""Top-level presubmit script for Fletch.

See http://dev.chromium.org/developers/how-tos/depottools/presubmit-scripts
for more details about the presubmit API built into gcl.
"""
# We have auto generated code that we do not want to lint.
NO_LINTING = (
    r"^pkg[\\\/]immi_samples[\\\/]lib[\\\/]ios[\\\/].*",
    r"^package[\\\/]immi[\\\/]objc[\\\/].*",
    r"^package[\\\/]service[\\\/]cc[\\\/].*"
    r"^package[\\\/]service[\\\/]java[\\\/]jni[\\\/].*",
    r"^samples[\\\/]github[\\\/]ios[\\\/].*",
    r"^samples[\\\/]buildbot[\\\/]cc[\\\/].*",
    r"^samples[\\\/]buildbot[\\\/]ios[\\\/].*",
    r"^samples[\\\/]buildbot[\\\/]java[\\\/]jni[\\\/].*",
    r"^samples[\\\/]buildbot[\\\/]objc[\\\/].*",
    r"^samples[\\\/]myapi[\\\/]generated[\\\/]java[\\\/]jni[\\\/].*",
    r"^samples[\\\/]todomvc[\\\/]cc[\\\/].*",
    r"^samples[\\\/]todomvc[\\\/]ios[\\\/].*",
    r"^samples[\\\/]todomvc[\\\/]java[\\\/]jni[\\\/].*",
    r"^tests[\\\/]service_tests[\\\/]conformance[\\\/]cc[\\\/].*",
    r"^tests[\\\/]service_tests[\\\/]conformance[\\\/]java[\\\/]jni[\\\/].*",
    r"^tests[\\\/]service_tests[\\\/]performance[\\\/]cc[\\\/].*",
    r"^tests[\\\/]service_tests[\\\/]performance[\\\/]java[\\\/]jni[\\\/].*",
    r"^third_party[\\\/]double-conversion[\\\/]src[\\\/].*",
    r"^tools[\\\/]immic[\\\/]lib[\\\/]src[\\\/]resources[\\\/]objc[\\\/].*",
    r"^tools[\\\/]servicec[\\\/]lib[\\\/]src[\\\/]resources[\\\/]cc[\\\/].*",
)

def CheckChangeOnCommit(input_api, output_api):
  results = []
  status_check = input_api.canned_checks.CheckTreeIsOpen(
      input_api,
      output_api,
      json_url='http://fletch-status.appspot.com/current?format=json')
  results.extend(status_check)
  results.extend(RunLint(input_api, output_api))
  return results

def CheckChangeOnUpload(input_api, output_api):
  return RunLint(input_api, output_api)


def RunLint(input_api, output_api):
  def FilterFile(file):
    return input_api.FilterSourceFile(file,
                                      black_list=NO_LINTING)
  result = []
  cpplint._cpplint_state.ResetErrorCounts()
  # Find all .cc and .h files in the change list.
  for f in input_api.AffectedSourceFiles(FilterFile):
    filename = f.AbsoluteLocalPath()
    if filename.endswith('.cc') or filename.endswith('.h'):
      # Run cpplint on the file.
      cpplint.ProcessFile(filename, 1)

  # Report a presubmit error if any of the files had an error.
  if cpplint._cpplint_state.error_count > 0:
    result = [output_api.PresubmitError('Failed cpplint check.')]
  return result
