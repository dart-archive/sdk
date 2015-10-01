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

const List<Example> untestable = const <Example>[const Untestable()];

List<Example> getExamples(DiagnosticKind kind) {
  switch (kind) {
    case DiagnosticKind.internalError:
      return untestable;

    case DiagnosticKind.verbRequiresNoSession:
      return <Example>[
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['create', 'session', 'bar', 'in', 'session', 'foo']),
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['help', 'all', 'in', 'session', 'foo'])];

    case DiagnosticKind.verbRequiresSessionTarget:
      return <Example>[
          new CommandLineExample(
              <String>['create']),
          new CommandLineExample(
              <String>['x-end'])];

    case DiagnosticKind.verbRequiresFileTarget:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['compile', 'session', 'foo', 'in', 'session', 'foo'])];

    case DiagnosticKind.verbRequiresSocketTarget:
      return <Example>[
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['attach', 'in', 'session', 'foo', 'file', 'fisk']),
          new CommandLineExample(
              // Same as previous example, except with an implict file target.
              <String>['create', 'session', 'foo'],
              <String>['attach', 'in', 'session', 'foo', 'fisk.dart'])];

    case DiagnosticKind.verbDoesNotSupportTarget:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['debug', 'sessions', 'in', 'session', 'foo'])];

    case DiagnosticKind.noSuchSession:
      return <Example>[
          new CommandLineExample(
              <String>['x-end', 'session', 'foo'])];

    case DiagnosticKind.sessionAlreadyExists:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['create', 'session', 'foo'])];

    case DiagnosticKind.noFileTarget:
      return <Example>[
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['compile', 'in', 'session', 'foo'])];

    case DiagnosticKind.noTcpSocketTarget:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['attach', 'in', 'session', 'foo'])];

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

    case DiagnosticKind.socketAgentConnectError:
      // TODO(wibling): figure out how to test fletch agent failures to
      // exercise this error.
      return untestable;

    case DiagnosticKind.socketAgentReplyError:
      // TODO(wibling): figure out how to test fletch agent failures to
      // exercise this error.
      return untestable;

    case DiagnosticKind.socketVmConnectError:
      return <Example>[new CommandLineExample(
            <String>['create', 'session', 'foo'],
            <String>['attach', 'in', 'session', 'foo',
                     'tcp_socket', invalidAddress])];

    case DiagnosticKind.socketVmReplyError:
      // TODO(wibling): figure out how to simulate fletch vm failures to
      // exercise this error.
      return untestable;

    case DiagnosticKind.attachToVmBeforeRun:
      return <Example>[
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['debug', 'in', 'session', 'foo']),
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['debug', 'run-to-main', 'in', 'session', 'foo']),
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['debug', 'backtrace', 'in', 'session', 'foo'])];

    case DiagnosticKind.compileBeforeRun:
      var examples = <Example>[
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['attach', 'in', 'session', 'foo',
                       'tcp_socket', exampleAddress],
              <String>['debug', 'in', 'session', 'foo']),
          new CommandLineExample(
              <String>['create', 'session', 'foo'],
              <String>['attach', 'in', 'session', 'foo',
                       'tcp_socket', exampleAddress],
              <String>['debug', 'attach', 'in', 'session', 'foo'])];
      // TODO(ahe): Need to mock up a VM socket to test this. But hopefully
      // we'll get rid of this message before then, most commands should
      // support auto-compiling.
      return untestable;

    case DiagnosticKind.missingToFile:
      return <Example>[
          new CommandLineExample(
              <String>['export'])];

    case DiagnosticKind.settingsCompileTimeConstantAsOption:
      return <Example>[new SettingsExample('{"options":["-Dfoo=bar"]}')];

    case DiagnosticKind.settingsConstantsNotAMap:
      return <Example>[new SettingsExample('{"constants":[]}')];

    case DiagnosticKind.settingsNotAMap:
      return <Example>[
          new SettingsExample('""'),
          new SettingsExample('null'),
          new SettingsExample('1'),
          new SettingsExample('[]')];

    case DiagnosticKind.settingsNotJson:
      return <Example>[
          new SettingsExample(''),
          new SettingsExample('{1:null}'),
          new SettingsExample('...')];

    case DiagnosticKind.settingsOptionNotAString:
      return <Example>[new SettingsExample('{"options":[1]}')];

    case DiagnosticKind.settingsOptionsNotAList:
      return <Example>[new SettingsExample('{"options":1}')];

    case DiagnosticKind.settingsPackagesNotAString:
      return <Example>[new SettingsExample('{"packages":1}')];

    case DiagnosticKind.settingsUnrecognizedConstantValue:
      return <Example>[new SettingsExample('{"constants":{"key": []}}')];

    case DiagnosticKind.settingsUnrecognizedKey:
      return <Example>[new SettingsExample('{"fisk":null}')];

    case DiagnosticKind.settingsDeviceAddressNotAString:
      return <Example>[new SettingsExample('{"device_address":1}')];

    case DiagnosticKind.unknownAction:
      return <Example>[
          new CommandLineExample(<String>['blah']),
          new CommandLineExample(<String>['--compile-and-run', 'test.dart']),
          new CommandLineExample(<String>['test.dart'])];

    case DiagnosticKind.extraArguments:
      return <Example>[
          new CommandLineExample(<String>['create', 'fisk'])];

    case DiagnosticKind.cantPerformVerbIn:
      return <Example>[
          new CommandLineExample(<String>['create', 'in', 'classes'])];

    case DiagnosticKind.cantPerformVerbTo:
      return <Example>[
          new CommandLineExample(<String>['create', 'to', 'classes'])];

    case DiagnosticKind.cantPerformVerbWith:
      return <Example>[
          new CommandLineExample(<String>['create', 'with', 'classes'])];

    case DiagnosticKind.duplicatedIn:
      return <Example>[new CommandLineExample(
            <String>['run', 'in', 'session', 'foo', 'in', 'session', 'foo'])];

    case DiagnosticKind.duplicatedTo:
      return <Example>[new CommandLineExample(
            <String>['export', 'to', 'foo.dart', 'to', 'foo.dart'])];

    case DiagnosticKind.duplicatedWith:
      return <Example>[new CommandLineExample(
            <String>['create', 'with', 'foo.txt', 'with', 'foo.txt'])];

    case DiagnosticKind.verbDoesntSupportTarget:
      return <Example>[new CommandLineExample(
            <String>['shutdown', 'foo.txt'])];

    case DiagnosticKind.verbRequiresNoToFile:
      return <Example>[new CommandLineExample(
            <String>['shutdown', 'to', 'foo.txt'])];

    case DiagnosticKind.verbRequiresNoWithFile:
      return <Example>[new CommandLineExample(
            <String>['shutdown', 'with', 'foo.txt'])];

    case DiagnosticKind.verbRequiresTarget:
      // TODO(ahe): Add test for this.
      return untestable;

    case DiagnosticKind.verbRequiresTargetButGot:
      // TODO(ahe): Add test for this.
      return untestable;
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

class SettingsExample extends Example {
  final String data;

  const SettingsExample(this.data);
}

class Untestable extends Example {
  const Untestable();
}
