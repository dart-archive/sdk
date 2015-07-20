// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.message_examples;

import 'messages.dart' show
    DiagnosticKind;

/// According to
/// http://stackoverflow.com/questions/10456044/what-is-a-good-invalid-ip-address-to-use-for-unit-tests,
/// any IP address starting with 0 is unroutable.
const String invalidIP = '0.42.42.42';

const String invalidAddress = '$invalidIP:61366';

const String exampleAddress = 'example.com:54321';

List<Example> getExamples(DiagnosticKind kind) {
  switch (kind) {
    case DiagnosticKind.internalError:
      throw new StateError("No example for $kind");

    case DiagnosticKind.verbRequiresSession:
      return <Example>[new CommandLineExample(<String>['compile'])];

    case DiagnosticKind.verbRequiresNoSession:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['create', 'session', 'bar', 'in', 'session', 'foo'])];

    case DiagnosticKind.noSuchSession:
      return <Example>[new CommandLineExample(
          <String>['compile', 'in', 'session', 'foo'])];

    case DiagnosticKind.sessionAlreadyExists:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['create', 'session', 'foo'])];

    case DiagnosticKind.noFileTarget:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['compile', 'in', 'session', 'foo'])];

    case DiagnosticKind.compileRequiresFileTarget:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['compile', 'session', 'foo', 'in', 'session', 'foo'])];

    case DiagnosticKind.noTcpSocketTarget:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['attach', 'in', 'session', 'foo'])];

    case DiagnosticKind.attachRequiresSocketTarget:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['attach', 'in', 'session', 'foo', 'file', 'fisk'])];

    case DiagnosticKind.expectedAPortNumber:
      return <Example>[
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['attach', 'in', 'session', 'foo',
                       'tcp_socket', ':fisk']),

          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['attach', 'in', 'session', 'foo',
                       'tcp_socket', '$invalidIP:fisk'])];

    case DiagnosticKind.socketConnectError:
      return <Example>[new CommandLineExample(
            <String>['create', 'session', 'foo'],
            <String>['attach', 'in', 'session', 'foo',
                     'tcp_socket', invalidAddress])];

    case DiagnosticKind.attachToVmBeforeRun:
      return <Example>[new CommandLineExample(
            <String>['create', 'session', 'foo'],
            <String>['x-run', 'in', 'session', 'foo'])];

    case DiagnosticKind.compileBeforeRun:
      return <Example>[new CommandLineExample(
            <String>['create', 'session', 'foo'],
            <String>['attach', 'in', 'session', 'foo',
                     'tcp_socket', exampleAddress],
            <String>['x-run', 'in', 'session', 'foo'])];

    case DiagnosticKind.noFile:
      // TODO(ahe): Remove this when compile_and_run_verb.dart is removed.
      return <Example>[new CommandLineExample(<String>['compile-and-run'])];
  }
}

abstract class Example {
  const Example();
}

class CommandLineExample extends Example {
  final List<String> line1;

  final List<String> line2;

  final List<String> line3;

  const CommandLineExample(this.line1, [this.line2, this.line3]);
}
