// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Messages used by fletch_test_suite.dart to communicate with test.py.
library fletch_tests.messages;

import 'dart:core' hide print;

import 'dart:convert' show
    JSON;

import 'dart:io' as io show stdout;

import 'dart:async' show
    StreamTransformer;

StreamTransformer get messageTransformer {
  return new StreamTransformer.fromHandlers(handleData: (line, sink) {
     sink.add(new Message.fromJson(line));
  });
}

abstract class Message {
  const Message();

  factory Message.fromJson(String json) {
    Map<String, dynamic> data = JSON.decode(json);
    String type = data['type'];
    switch (type) {
      case 'InternalErrorMessage': return new ErrorMessage.fromJsonData(data);
      case 'Info': return new Info.fromJsonData(data);
      case 'ListTests': return const ListTests();
      case 'ListTestsReply': return new ListTestsReply.fromJsonData(data);
      case 'RunTest': return new RunTest.fromJsonData(data);
      case 'TestFailed': return new TestFailed.fromJsonData(data);
      case 'TestPassed': return new TestPassed.fromJsonData(data);
    }

    throw "Unknown message: $type";
  }

  String get type;

  String toString() => "$type()";

  Map<String, dynamic> toJson() => <String, dynamic>{'type': type};

  void print() {
    io.stdout.write('${JSON.encode(this)}\n');
  }
}

/// Notify that an error occurred.
abstract class ErrorMessage extends Message {
  final String error;

  final String stackTrace;

  ErrorMessage(this.error, this.stackTrace);

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
abstract class InternalErrorMessage extends Message {
  InternalErrorMessage(String error, String stackTrace)
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

/// Request that test [name] is run.
class RunTest extends Message {
  final String name;

  const RunTest(this.name);

  RunTest.fromJsonData(Map<String, dynamic> data)
      : this(data['name']);

  String get type => 'RunTest';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['name'] = name;
    return result;
  }

  String toString() => "$type($name)";
}

/// Test [name] failed. A possible reply to [RunTest].
class TestFailed extends ErrorMessage {
  final String name;
  final String stdout;

  TestFailed(this.name, this.stdout, String error, String stackTrace)
      : super(error, stackTrace);

  TestFailed.fromJsonData(Map<String, dynamic> data)
      : this(data['name'], data['stdout'], data['error'], data['stackTrace']);

  String get type => 'TestFailed';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['name'] = name;
    result['stdout'] = stdout;
    return result;
  }

  String toString() => "$type($name, $stdout, $error, $stackTrace)";
}

/// Test [name] passed. A possible reply to [RunTest].
class TestPassed extends Message {
  final String name;
  final String stdout;

  const TestPassed(this.name, this.stdout);

  TestPassed.fromJsonData(Map<String, dynamic> data)
      : this(data['name'], data['stdout']);

  String get type => 'TestPassed';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = super.toJson();
    result['name'] = name;
    result['stdout'] = stdout;
    return result;
  }

  String toString() => "$type($name, $stdout)";
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
