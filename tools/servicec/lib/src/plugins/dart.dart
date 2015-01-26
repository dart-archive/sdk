// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.dart;

import 'dart:core' hide Type;

import 'package:path/path.dart' show basenameWithoutExtension;

import '../parser.dart';
import '../emitter.dart';

const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

void generate(String path, Unit unit, String outputDirectory) {
  _DartVisitor visitor = new _DartVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  writeToFile(outputDirectory, path, "dart", contents);
}

class _DartVisitor extends Visitor {
  final String path;
  final StringBuffer buffer = new StringBuffer();
  final List<String> methods = new List();
  _DartVisitor(this.path);

  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    buffer.writeln(COPYRIGHT);

    buffer.writeln('// Generated file. Do not edit.');
    buffer.writeln();

    String libraryName = basenameWithoutExtension(path);
    buffer.writeln('library $libraryName;');
    buffer.writeln();

    buffer.writeln('import "dart:ffi";');
    buffer.writeln('import "dart:service" as service;');
    buffer.writeln();

    buffer.writeln('final Channel _channel = new Channel();');
    buffer.writeln('final Port _port = new Port(_channel);');
    buffer.write('final Foreign _postResult = ');
    buffer.writeln('Foreign.lookup("PostResultToService");');

    node.services.forEach(visit);
  }

  visitService(Service node) {
    String serviceName = node.name;

    buffer.writeln();
    buffer.writeln('bool _terminated = false;');
    buffer.writeln('$serviceName _impl;');

    buffer.writeln();
    buffer.writeln('abstract class $serviceName {');

    node.methods.forEach(visit);

    buffer.writeln();
    buffer.writeln('  static void initialize($serviceName impl) {');
    buffer.writeln('    if (_impl != null) {');
    buffer.writeln('      throw new UnsupportedError();');
    buffer.writeln('    }');
    buffer.writeln('    _impl = impl;');
    buffer.writeln('    _terminated = false;');
    buffer.writeln('    service.register("$serviceName", _port);');
    buffer.writeln('  }');

    buffer.writeln();
    buffer.writeln('  static bool hasNextEvent() {');
    buffer.writeln('    return !_terminated;');
    buffer.writeln('  }');

    List<String> methodIds
        = methods.map((name) => '_${name.toUpperCase()}_METHOD_ID').toList();

    buffer.writeln();
    buffer.writeln('  static void handleNextEvent() {');
    buffer.writeln('    var request = _channel.receive();');
    buffer.writeln('    switch (request.getInt32(0)) {');
    buffer.writeln('      case _TERMINATE_METHOD_ID:');
    buffer.writeln('        _terminated = true;');
    buffer.writeln('        _postResult.icall\$1(request);');
    buffer.writeln('        break;');
    String getInt = 'request.getInt32(4)';
    String setInt = 'request.setInt32(4, result)';
    for (int i = 0; i < methods.length; ++i) {
      buffer.writeln('      case ${methodIds[i]}:');
      buffer.writeln('        var result = _impl.${methods[i]}($getInt);');
      buffer.writeln('        $setInt;');
      buffer.writeln('        _postResult.icall\$1(request);');
      buffer.writeln('        break;');
    }
    buffer.writeln('      default:');
    buffer.writeln('        throw UnsupportedError();');
    buffer.writeln('    }');
    buffer.writeln('  }');

    buffer.writeln();
    int nextId = 0;
    buffer.writeln('  const int _TERMINATE_METHOD_ID = ${nextId++};');
    for (String id in methodIds) {
      buffer.writeln('  const int $id = ${nextId++};');
    }

    buffer.writeln('}');
  }

  visitMethod(Method node) {
    String methodName = node.name;
    methods.add(methodName);
    buffer.writeln('  int $methodName(int argument);');
  }

  visitType(Type node) {
    throw new Exception("Not used.");
  }
}

