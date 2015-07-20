// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.message_examples;

import 'messages.dart' show
    DiagnosticKind;

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

  const CommandLineExample(this.line1, [this.line2]);
}
