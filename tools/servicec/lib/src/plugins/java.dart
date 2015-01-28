// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.java;

import 'dart:core' hide Type;

import 'package:path/path.dart' show basenameWithoutExtension, join;
import 'package:strings/strings.dart' as strings;

import '../emitter.dart';
import '../parser.dart';

import 'cc.dart' show CcVisitor;

const HEADER = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.
""";

const FLETCH_API_JAVA = """
package fletch;

public class FletchApi {
  public static native void Setup();
  public static native void TearDown();
  public static native void RunSnapshot(byte[] snapshot);
  public static native void AddDefaultSharedLibrary(String library);
}
""";

const FLETCH_SERVICE_API_JAVA = """
package fletch;

public class FletchServiceApi {
  public static native void Setup();
  public static native void TearDown();
}
""";

const FLETCH_API_JAVA_IMPL = """
#include <jni.h>

#include "fletch_api.h"

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT void JNICALL Java_fletch_FletchApi_Setup(JNIEnv*, jclass) {
  FletchSetup();
}

JNIEXPORT void JNICALL Java_fletch_FletchApi_TearDown(JNIEnv*, jclass) {
  FletchTearDown();
}

JNIEXPORT void JNICALL Java_fletch_FletchApi_RunSnapshot(JNIEnv* env,
                                                         jclass,
                                                         jbyteArray snapshot) {
  int len = env->GetArrayLength(snapshot);
  unsigned char* copy = new unsigned char[len];
  env->GetByteArrayRegion(snapshot, 0, len, reinterpret_cast<jbyte*>(copy));
  FletchRunSnapshot(copy, len);
  delete copy;
}

JNIEXPORT void JNICALL Java_fletch_FletchApi_AddDefaultSharedLibrary(
    JNIEnv* env, jclass, jstring str) {
  const char* library = env->GetStringUTFChars(str, 0);
  FletchAddDefaultSharedLibrary(library);
  env->ReleaseStringUTFChars(str, library);
}

#ifdef __cplusplus
}
#endif
""";

const FLETCH_SERVICE_API_JAVA_IMPL = """
#include <jni.h>

#include "service_api.h"

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT void JNICALL Java_fletch_FletchServiceApi_Setup(JNIEnv*, jclass) {
  ServiceApiSetup();
}

JNIEXPORT void JNICALL Java_fletch_FletchServiceApi_TearDown(JNIEnv*, jclass) {
  ServiceApiTearDown();
}

#ifdef __cplusplus
}
#endif
""";

void generate(String path, Unit unit, String outputDirectory) {
  _generateFletchApis(outputDirectory);
  _generateServiceJava(path, unit, outputDirectory);
  _generateServiceJni(path, unit, outputDirectory);
}

void _generateFletchApis(String outputDirectory) {
  String fletchDirectory = join(outputDirectory, 'java', 'fletch');
  String jniDirectory = join(outputDirectory, 'java', 'jni');

  StringBuffer buffer = new StringBuffer(HEADER);
  buffer.writeln();
  buffer.write(FLETCH_API_JAVA);
  writeToFile(fletchDirectory, 'FletchApi', 'java', buffer.toString());

  buffer = new StringBuffer(HEADER);
  buffer.writeln();
  buffer.write(FLETCH_SERVICE_API_JAVA);
  writeToFile(fletchDirectory, 'FletchServiceApi', 'java', buffer.toString());

  buffer = new StringBuffer(HEADER);
  buffer.writeln();
  buffer.write(FLETCH_API_JAVA_IMPL);
  writeToFile(jniDirectory, 'fletch_api_wrapper', 'cc', buffer.toString());

  buffer = new StringBuffer(HEADER);
  buffer.writeln();
  buffer.write(FLETCH_SERVICE_API_JAVA_IMPL);
  writeToFile(jniDirectory,
              'fletch_service_api_wrapper',
              'cc',
              buffer.toString());
}

void _generateServiceJava(String path, Unit unit, String outputDirectory) {
  _JavaVisitor visitor = new _JavaVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'java', 'fletch');
  // TODO(ager): We should generate a file per service here.
  if (unit.services.length > 1) {
    print('Java plugin: multiple services in one file is not supported.');
  }
  String serviceName = unit.services.first.name;
  writeToFile(directory, serviceName, "java", contents);
}

void _generateServiceJni(String path, Unit unit, String outputDirectory) {
  _JniVisitor visitor = new _JniVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'java', 'jni');
  // TODO(ager): We should generate a file per service here.
  if (unit.services.length > 1) {
    print('Java plugin: multiple services in one file is not supported.');
  }
  String serviceName = unit.services.first.name;
  String file = '${strings.underscore(serviceName)}_wrapper';
  writeToFile(directory, file, "cc", contents);
}

class _JavaVisitor extends Visitor {
  final String path;
  final StringBuffer buffer = new StringBuffer();

  _JavaVisitor(this.path);

  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    buffer.writeln(HEADER);
    buffer.writeln('package fletch;');
    node.services.forEach(visit);
  }

  visitService(Service node) {
    buffer.writeln();
    buffer.writeln('public class ${node.name} {');
    buffer.writeln('  public static native void Setup();');
    buffer.writeln('  public static native void TearDown();');
    node.methods.forEach(visit);
    buffer.writeln('}');
  }

  visitMethod(Method node) {
    buffer.write('  public static native ');
    visit(node.returnType);
    buffer.write(' ${node.name}(');
    visitArguments(node.arguments);
    buffer.writeln(');');
  }

  visitArguments(List<Formal> formals) {
    bool first = true;
    formals.forEach((Formal formal) {
      if (!first) buffer.write(', ');
      first = false;
      visit(formal);
    });
  }

  visitFormal(Formal node) {
    visit(node.type);
    buffer.write(' ${node.name}');
  }

  visitType(Type node) {
    Map<String, String> types = const { 'Int32': 'int' };
    String type = types[node.identifier];
    buffer.write(type);
  }
}

class _JniVisitor extends CcVisitor {
  int methodId = 1;
  String serviceName;

  _JniVisitor(String path) : super(path);

  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    buffer.writeln(HEADER);
    buffer.writeln('#include <jni.h>');
    buffer.writeln();
    buffer.writeln('#include "service_api.h"');
    node.services.forEach(visit);
  }

  visitService(Service node) {
    serviceName = node.name;

    buffer.writeln();

    buffer.writeln('#ifdef __cplusplus');
    buffer.writeln('extern "C" {');
    buffer.writeln('#endif');

    buffer.writeln();
    buffer.writeln('static ServiceId _service_id = kNoServiceId;');

    buffer.writeln();
    buffer.write('JNIEXPORT void JNICALL Java_fletch_');
    buffer.writeln('${serviceName}_Setup(JNIEnv*, jclass) {');
    buffer.writeln('  _service_id = ServiceApiLookup("$serviceName");');
    buffer.writeln('}');

    buffer.writeln();
    buffer.write('JNIEXPORT void JNICALL Java_fletch_');
    buffer.writeln('${serviceName}_TearDown(JNIEnv*, jclass) {');
    buffer.writeln('  ServiceApiTerminate(_service_id);');
    buffer.writeln('}');

    node.methods.forEach(visit);

    buffer.writeln();
    buffer.writeln('#ifdef __cplusplus');
    buffer.writeln('}');
    buffer.writeln('#endif');
  }

  visitMethod(Method node) {
    String name = node.name;
    String id = '_k${name}Id';

    buffer.writeln();
    buffer.write('static const MethodId $id = ');
    buffer.writeln('reinterpret_cast<MethodId>(${methodId++});');

    buffer.writeln();
    buffer.write('JNIEXPORT ');
    visit(node.returnType);
    buffer.write(' JNICALL Java_fletch_${serviceName}_${name}(');
    buffer.write('JNIEnv*, jclass, ');
    visitArguments(node.arguments);
    buffer.writeln(') {');
    visitMethodBody(id, node.arguments);
    buffer.writeln('}');
  }

  visitType(Type node) {
    Map<String, String> types = const { 'Int32': 'jint' };
    String type = types[node.identifier];
    buffer.write(type);
  }
}