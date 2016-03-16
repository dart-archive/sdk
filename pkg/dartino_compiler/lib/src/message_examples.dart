// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.message_examples;

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

    case DiagnosticKind.projectAlreadyExists:
      // TODO(danrubel): figure out a way to test this.
      // Basically we need to create a directory on disk
      // then call 'dartino project create' on that directory.
      return untestable;

    case DiagnosticKind.missingRequiredArgument:
      // TODO(danrubel) create a test
      return untestable;

    case DiagnosticKind.missingForName:
      return <Example>[new CommandLineExample(
          <String>['create', 'project', 'foo'],
          <String>['create', 'project', 'foo', 'for'])];

    case DiagnosticKind.boardNotFound:
      // TODO(danrubel): figure out a way to test this
      // by getting sdkUri to be set correctly.
      // return <Example>[new CommandLineExample(
      //     <String>['create', 'project', 'foo', 'for', 'baz-board'])];
      return untestable;

    case DiagnosticKind.noSuchSession:
      return <Example>[
          new CommandLineExample(
              <String>['x-end', 'session', 'foo'])];

    case DiagnosticKind.sessionAlreadyExists:
      return <Example>[new CommandLineExample(
          <String>['create', 'session', 'foo'],
          <String>['create', 'session', 'foo'])];

    case DiagnosticKind.sessionInvalidState:
      // TODO(wibling): figure out a way to test this.
      // Basically we need to have a dartino-vm that is
      // explicitly attached to via 'dartino attach' and
      // have it in a state where it has thrown an uncaught
      // exception and then call e.g. 'dartino run foo.dart'.
      return untestable;

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

    case DiagnosticKind.noAgentFound:
      // TODO(karlklose,268): We want to write a test similar to the following,
      // but it records the error in the wrong isolate. We need a way to
      // test this.
      //   return <Example>[new CommandLineExample(
      //      <String>['create', 'session', 'foo'],
      //      <String>['x-upgrade', 'agent',
      //        'with', 'file', 'dartino-agent_v1_platform.deb',
      //        'in', 'session', 'foo'
      //      ])];
      return untestable;

    case DiagnosticKind.upgradeInvalidPackageName:
      // TODO(karlklose,268): We want to write a test similar to the following,
      // but it records the error in the wrong isolate. We need a way to
      // test this.
      // return <Example>[new CommandLineExample(
      //     <String>['x-upgrade', 'agent', 'with', 'file',
      //              'invalid-file-name'])];
      return untestable;

    case DiagnosticKind.socketAgentConnectError:
      // TODO(wibling,268): figure out how to test dartino agent failures to
      // exercise this error.
      return untestable;

    case DiagnosticKind.socketAgentReplyError:
      // TODO(wibling,268): figure out how to test dartino agent failures to
      // exercise this error.
      return untestable;

    case DiagnosticKind.socketVmConnectError:
      return <Example>[new CommandLineExample(
            <String>['create', 'session', 'foo'],
            <String>['attach', 'in', 'session', 'foo',
                     'tcp_socket', invalidAddress])];

    case DiagnosticKind.socketVmReplyError:
      // TODO(wibling): figure out how to simulate dartino vm failures to
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

    case DiagnosticKind.missingProjectPath:
      return <Example>[new CommandLineExample(
            <String>['create', 'project'])];

    case DiagnosticKind.missingSessionName:
      return <Example>[new CommandLineExample(
            <String>['create', 'session'])];

    case DiagnosticKind.unknownOption:
      return <Example>[
          new CommandLineExample(<String>['help', '--fisk']),
          new CommandLineExample(<String>['--compile-and-run', 'test.dart'])];

    case DiagnosticKind.unsupportedPlatform:
      return untestable;

    case DiagnosticKind.unexpectedArgument:
      return <Example>[new CommandLineExample(
            <String>['help', '--version=fisk'])];

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

    case DiagnosticKind.settingsDeviceTypeNotAString:
      return <Example>[new SettingsExample('{"device_type":1}')];

    case DiagnosticKind.settingsDeviceTypeUnrecognized:
      return <Example>[new SettingsExample('{"device_type":"fisk"}')];

    case DiagnosticKind.settingsIncrementalModeNotAString:
      return <Example>[new SettingsExample('{"incremental_mode":1}')];

    case DiagnosticKind.settingsIncrementalModeUnrecognized:
      return <Example>[new SettingsExample('{"incremental_mode":"fisk"}')];

    case DiagnosticKind.unknownAction:
      return <Example>[
          new CommandLineExample(<String>['blah']),
          new CommandLineExample(<String>['test.dart'])];

    case DiagnosticKind.missingNoun:
      return <Example>[
          new CommandLineExample(<String>['create'])];

    case DiagnosticKind.unknownNoun:
      return <Example>[
          new CommandLineExample(<String>['create foo'])];

    case DiagnosticKind.extraArguments:
      return <Example>[
          new CommandLineExample(<String>['create', 'fisk']),
          new CommandLineExample(<String>['x-upgrade', 'hest']),
      ];

    case DiagnosticKind.cantPerformVerbIn:
      return <Example>[
          new CommandLineExample(
              <String>['create', 'project', 'foo', 'in', 'classes'])];

    case DiagnosticKind.cantPerformVerbTo:
      return <Example>[
          new CommandLineExample(<String>[
              'create', 'project', 'foo', 'to', 'classes'])];

    case DiagnosticKind.cantPerformVerbWith:
      return <Example>[
          new CommandLineExample(<String>[
              'create', 'project', 'foo', 'with', 'classes'])];

    case DiagnosticKind.duplicatedFor:
      return <Example>[new CommandLineExample(<String>[
        'create', 'project', 'foo', 'for', 'bar', 'for', 'baz'])];

    case DiagnosticKind.duplicatedIn:
      return <Example>[new CommandLineExample(
            <String>['run', 'in', 'session', 'foo', 'in', 'session', 'foo'])];

    case DiagnosticKind.duplicatedTo:
      return <Example>[new CommandLineExample(
            <String>['export', 'to', 'foo.dart', 'to', 'foo.dart'])];

    case DiagnosticKind.duplicatedWith:
      return <Example>[new CommandLineExample(<String>[
          'create', 'session', 'foo', 'with', 'bar.dart', 'with', 'baz.dart'])];

    case DiagnosticKind.verbDoesntSupportTarget:
      // Though the quit verb is not a real verb it can still be used to provoke
      // this failure as part of sentence parsing.
      return <Example>[new CommandLineExample(
            <String>['quit', 'foo.txt'])];

    case DiagnosticKind.verbRequiresNoFor:
      // Though the quit verb is not a real verb it can still be used to provoke
      // this failure as part of sentence parsing.
      return <Example>[
        new CommandLineExample(
            <String>['quit', 'for', 'foo']),
      ];

    case DiagnosticKind.verbRequiresNoToFile:
      // Though the quit verb is not a real verb it can still be used to provoke
      // this failure as part of sentence parsing.
      return <Example>[
        new CommandLineExample(
            <String>['quit', 'to', 'foo.txt']),
        new CommandLineExample(
            <String>['x-upgrade', 'agent', 'foo.txt']),
      ];

    case DiagnosticKind.verbRequiresNoWithFile:
      // Though the quit verb is not a real verb it can still be used to provoke
      // this failure as part of sentence parsing.
      return <Example>[new CommandLineExample(
            <String>['quit', 'with', 'foo.txt'])];

    case DiagnosticKind.verbRequiresTarget:
      return <Example>[new CommandLineExample(
            <String>['show'])];

    case DiagnosticKind.verbRequiresSpecificTarget:
      return <Example>[new CommandLineExample(
            <String>['x-upgrade'])];

    case DiagnosticKind.verbRequiresSpecificTargetButGot:
      return <Example>[new CommandLineExample(
            <String>['x-upgrade', 'file', 'foo'])];

    case DiagnosticKind.expectedTargetButGot:
      return <Example>[new CommandLineExample(
            <String>['export', 'hello.dart', 'to', 'hello'])];

    case DiagnosticKind.quitTakesNoArguments:
      return <Example>[new CommandLineExample(<String>['quit', '-v'])];

    case DiagnosticKind.illegalDefine:
      return <Example>[new CommandLineExample(<String>['-Dfoo=1=2', 'run'])];

    case DiagnosticKind.infoFileNotFound:
      var examples = <Example>[new CommandLineExample(
          <String>['attach', 'tcp_socket', exampleAddress,
                   'in', 'session', 'foo'],
          <String>['debug', 'with', 'not_existing.snapshot',
                   'in', 'session', 'foo'])];
      // TODO(sigurdm): Need to mock up a VM socket to test this.
      return untestable;

    case DiagnosticKind.malformedInfoFile:
      // TODO(sigurdm): Need to mock up a VM socket to test this.
      return untestable;


    case DiagnosticKind.busySession:
      // TODO(ahe): Add test for this.
      return untestable;

    case DiagnosticKind.terminatedSession:
      // TODO(ahe): Add test for this.
      return untestable;

    case DiagnosticKind.handShakeFailed:
      // TODO(ager): We could probably test this with a mock VM.
      return untestable;

    case DiagnosticKind.versionMismatch:
      // TODO(ager): We could probably test this with a mock VM.
      return untestable;

    case DiagnosticKind.agentVersionMismatch:
      // TODO(wibling): Add test for this
      return untestable;

    case DiagnosticKind.compilerVersionMismatch:
      // TODO(wibling): Add test for this
      return untestable;

    case DiagnosticKind.toolsNotInstalled:
      // TODO(sgjesse): Add test for this
      return untestable;

    case DiagnosticKind.snapshotHashMismatch:
      // TODO(sigurdm): Add test for this.
      // We could probably test this with a mock VM.
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
