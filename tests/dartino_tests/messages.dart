// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Messages used by dartino_test_suite.dart to communicate with test.py.
library dartino_tests.messages;

import 'dart:convert' show
    JSON;

import 'dart:async' show
    StreamTransformer;

StreamTransformer<String, Message> get messageTransformer {
  return new StreamTransformer<String, Message>
      .fromHandlers(handleData: (String line, Sink<Message> sink) {
     sink.add(new Message.fromJson(line));
  });
}

abstract class Message {
  const Message();

  factory Message.fromJson(String json) {
    Map<String, dynamic> data = JSON.decode(json);
    String type = data['type'];
    switch (type) {
      case 'InternalErrorMessage':
        return new InternalErrorMessage.fromJsonData(data);

      case 'Info': return new Info.fromJsonData(data);
      case 'ListTests': return const ListTests();
      case 'ListTestsReply': return new ListTestsReply.fromJsonData(data);
      case 'RunTest': return new RunTest.fromJsonData(data);
      case 'TimedOut': return new TimedOut.fromJsonData(data);
      case 'TestFailed': return new TestFailed.fromJsonData(data);
      case 'TestPassed': return new TestPassed.fromJsonData(data);
      case 'TestStdoutLine': return new TestStdoutLine.fromJsonData(data);
    }

    throw "Unknown message: $type";
  }

  String get type;

  String toString() => "$type()";

  Map<String, dynamic> toJson() => <String, dynamic>{'type': type};

  void addTo(StringSink sink) {
    sink.writeln(JSON.encode(this));
  }
}

/// Notify that an error occurred.
abstract class ErrorMessage extends Message {
  final String error;

  final String stackTrace;

  const ErrorMessage(this.error, this.stackTrace);

  ErrorMessage.fromJsonData(Map<String, dynamic> data)
      : this(data['error'], data['stackTrace']);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['error'] = '$error';
    result['stackTrace'] = stackTrace == null ? null : '$stackTrace';
    return result;
  }

  String toString() => "$type($error,$stackTrace)";
}

/// Notify that an internal error occurred in this framework (there's a bug in
/// the framework).
class InternalErrorMessage extends ErrorMessage {
  const InternalErrorMessage(String error, String stackTrace)
      : super(error, stackTrace);

  InternalErrorMessage.fromJsonData(Map<String, dynamic> data)
      : super.fromJsonData(data);

  String get type => 'InternalErrorMessage';
}

/// Request a listing of all tests.
class ListTests extends Message {
  const ListTests();

  String get type => 'ListTests';
}

/// List of all tests (the response to [ListTests]).
class ListTestsReply extends Message {
  final List<String> tests;

  const ListTestsReply(this.tests);

  ListTestsReply.fromJsonData(Map<String, dynamic> data)
      : this(data['tests']);

  String get type => 'ListTestsReply';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['tests'] = tests;
    return result;
  }

  String toString() => "$type($tests)";
}

/// Abstract message with a name.
abstract class NamedMessage extends Message {
  final String name;

  const NamedMessage(this.name);

  NamedMessage.fromJsonData(Map<String, dynamic> data)
      : this(data['name']);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['name'] = name;
    return result;
  }

  String toString() => "$type($name)";
}

/// Request that test [name] is run.
class RunTest extends NamedMessage {
  const RunTest(String name)
      : super(name);

  RunTest.fromJsonData(Map<String, dynamic> data)
      : super.fromJsonData(data);

  String get type => 'RunTest';
}

/// Notify that test [name] timed out.
///
/// This message is bi-directional, it is used by test.dart to tell
/// dartino_test_suite.dart that a test has timed out, as well as by
/// dartino_test_suite.dart to tell test.dart that the test did in fact time out
/// (due to interprocess communication, and lack of synchronization, it is
/// possible for a test to complete normally before it is terminated).
class TimedOut extends NamedMessage {
  const TimedOut(String name)
      : super(name);

  TimedOut.fromJsonData(Map<String, dynamic> data)
      : super.fromJsonData(data);

  String get type => 'TimedOut';
}

/// Test [name] failed. A possible reply to [RunTest].
class TestFailed extends ErrorMessage implements NamedMessage {
  final String name;
  final String kind;

  const TestFailed(this.name, String error, String stackTrace, {this.kind})
      : super(error, stackTrace);

  TestFailed.fromJsonData(Map<String, dynamic> data)
      : this(data['name'], data['error'], data['stackTrace'],
             kind: data['kind']);

  String get type => 'TestFailed';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['name'] = name;
    result['kind'] = kind;
    return result;
  }

  String toString() => "$type($name, $error, $stackTrace)";
}

/// Test [name] passed. A possible reply to [RunTest].
class TestPassed extends NamedMessage {
  const TestPassed(String name)
      : super(name);

  TestPassed.fromJsonData(Map<String, dynamic> data)
      : this(data['name']);

  String get type => 'TestPassed';
}

/// Debug information.
class Info extends Message {
  final String data;

  const Info(this.data);

  Info.fromJsonData(Map<String, dynamic> data)
      : this(data['data']);

  String get type => 'Info';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['data'] = data;
    return result;
  }

  String toString() => "$type('$data')";
}

/// A line on stdout from test [name].
class TestStdoutLine extends NamedMessage {
  final String line;

  const TestStdoutLine(String name, this.line)
      : super(name);

  TestStdoutLine.fromJsonData(Map<String, dynamic> data)
      : this(data['name'], data['line']);

  String get type => 'TestStdoutLine';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['line'] = line;
    return result;
  }

  String toString() => "$type($name, $line)";
}
