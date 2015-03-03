// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.java;

import 'dart:core' hide Type;
import 'dart:io';

import 'package:path/path.dart';
import 'package:strings/strings.dart' as strings;

import 'shared.dart';
import '../emitter.dart';
import '../struct_layout.dart';

import 'cc.dart' show CcVisitor;

const HEADER = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.
""";

const HEADER_MK = """
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Generated file. Do not edit.
""";

const READER_HEADER = """
package fletch;
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

const JNI_UTILS = """
static JNIEnv* attachCurrentThreadAndGetEnv(JavaVM* vm) {
  AttachEnvType result = NULL;
  if (vm->AttachCurrentThread(&result, NULL) != JNI_OK) {
    // TODO(ager): Nicer error recovery?
    exit(1);
  }
  return reinterpret_cast<JNIEnv*>(result);
}

static void detachCurrentThread(JavaVM* vm) {
  if (vm->DetachCurrentThread() != JNI_OK) {
    // TODO(ager): Nicer error recovery?
    exit(1);
  }
}

static jobject createByteArray(JNIEnv* env, char* memory, int size) {
  jbyteArray result = env->NewByteArray(size);
  jbyte* contents = reinterpret_cast<jbyte*>(memory);
  env->SetByteArrayRegion(result, 0, size, contents);
  free(memory);
  return result;
}

static jobject createByteArrayArray(JNIEnv* env, char* memory, int size) {
  jobjectArray array = env->NewObjectArray(size, env->FindClass("[B"), NULL);
  for (int i = 0; i < size; i++) {
    int64_t address = *reinterpret_cast<int64_t*>(memory + (i * 16));
    int size = *reinterpret_cast<int*>(memory + 8 + (i * 16));
    char* contents = reinterpret_cast<char*>(address);
    env->SetObjectArrayElement(array, i, createByteArray(env, contents, size));
  }
  free(memory);
  return array;
}

static jobject getRootSegment(JNIEnv* env, char* memory) {
  int32_t segments = *reinterpret_cast<int32_t*>(memory);
  if (segments == 0) {
    int32_t size = *reinterpret_cast<int32_t*>(memory + 4);
    return createByteArray(env, memory, size);
  }
  return createByteArrayArray(env, memory + 8, segments);
}""";

const List<String> JAVA_RESOURCES = const [
  "Reader.java",
];

void generate(String path, Unit unit, String outputDirectory) {
  _generateFletchApis(outputDirectory);
  _generateServiceJava(path, unit, outputDirectory);
  _generateServiceJni(path, unit, outputDirectory);
  _generateServiceJniMakeFiles(path, unit, outputDirectory);

  String resourcesDirectory = join(dirname(Platform.script.path),
      '..', 'lib', 'src', 'resources', 'java', 'fletch');
  String fletchDirectory = join(outputDirectory, 'java', 'fletch');
  for (String resource in JAVA_RESOURCES) {
    String resourcePath = join(resourcesDirectory, resource);
    File file = new File(resourcePath);
    String contents = file.readAsStringSync();
    writeToFile(fletchDirectory, resource, contents);
  }
}

void _generateFletchApis(String outputDirectory) {
  String fletchDirectory = join(outputDirectory, 'java', 'fletch');
  String jniDirectory = join(outputDirectory, 'java', 'jni');

  StringBuffer buffer = new StringBuffer(HEADER);
  buffer.writeln();
  buffer.write(FLETCH_API_JAVA);
  writeToFile(fletchDirectory, 'FletchApi', buffer.toString(),
      extension: 'java');

  buffer = new StringBuffer(HEADER);
  buffer.writeln();
  buffer.write(FLETCH_SERVICE_API_JAVA);
  writeToFile(fletchDirectory, 'FletchServiceApi', buffer.toString(),
      extension: 'java');

  buffer = new StringBuffer(HEADER);
  buffer.writeln();
  buffer.write(FLETCH_API_JAVA_IMPL);
  writeToFile(jniDirectory, 'fletch_api_wrapper', buffer.toString(),
      extension: 'cc');

  buffer = new StringBuffer(HEADER);
  buffer.writeln();
  buffer.write(FLETCH_SERVICE_API_JAVA_IMPL);
  writeToFile(jniDirectory, 'fletch_service_api_wrapper', buffer.toString(),
      extension: 'cc');
}

void _generateServiceJava(String path, Unit unit, String outputDirectory) {
  _JavaVisitor visitor = new _JavaVisitor(path, outputDirectory);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'java', 'fletch');
  // TODO(ager): We should generate a file per service here.
  if (unit.services.length > 1) {
    print('Java plugin: multiple services in one file is not supported.');
  }
  String serviceName = unit.services.first.name;
  writeToFile(directory, serviceName, contents, extension: 'java');
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
  writeToFile(directory, file, contents, extension: 'cc');
}

class _JavaVisitor extends CodeGenerationVisitor {
  final String outputDirectory;

  _JavaVisitor(String path, String this.outputDirectory) : super(path);

  static const PRIMITIVE_TYPES = const <String, String> {
    'void'    : 'void',
    'bool'    : 'boolean',

    'uint8'   : 'short',
    'uint16'  : 'int',
    'uint32'  : 'long',
    // TODO(ager): consider how to deal with unsigned 64 bit integers.

    'int8'    : 'byte',
    'int16'   : 'short',
    'int32'   : 'int',
    'int64'   : 'long',

    'float32' : 'float',
    'float64' : 'double',
  };

  String getType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      return '${node.identifier}Builder';
    } else {
      String type = PRIMITIVE_TYPES[node.identifier];
      return type;
    }
  }

  String getReturnType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      return '${node.identifier}';
    } else {
      String type = PRIMITIVE_TYPES[node.identifier];
      return type;
    }
  }

  void writeType(Type node) => write(getType(node));
  void writeTypeToBuffer(Type node, StringBuffer buffer) {
    buffer.write(getType(node));
  }

  void writeReturnType(Type node) => write(getReturnType(node));
  void writeReturnTypeToBuffer(Type node, StringBuffer buffer) {
    buffer.write(getReturnType(node));
  }

  visitUnit(Unit node) {
    writeln(HEADER);
    writeln('package fletch;');
    writeln();
    node.structs.forEach(visit);
    node.services.forEach(visit);
  }

  visitService(Service node) {
    writeln();
    writeln('public class ${node.name} {');
    writeln('  public static native void Setup();');
    writeln('  public static native void TearDown();');
    node.methods.forEach(visit);
    writeln('}');
  }

  visitMethod(Method node) {
    if (node.inputKind != InputKind.PRIMITIVES) return;

    String name = node.name;
    String camelName = name.substring(0, 1).toUpperCase() + name.substring(1);
    writeln();
    writeln('  public static abstract class ${camelName}Callback {');
    write('    public abstract void handle(');
    if (!node.returnType.isVoid) {
      writeReturnType(node.returnType);
      write(' result');
    }
    writeln(');');
    writeln('  }');

    writeln();
    if (node.outputKind != OutputKind.PRIMITIVE) {
      write('  private static native Object ${name}_raw(');
    } else {
      write('  public static native ');
      writeReturnType(node.returnType);
      write(' $name(');
    }
    visitArguments(node.arguments);
    writeln(');');
    write('  public static native void ${name}Async(');
    visitArguments(node.arguments);
    if (!node.arguments.isEmpty) write(', ');
    writeln('${camelName}Callback callback);');

    if (node.outputKind != OutputKind.PRIMITIVE) {
      write('  public static ');
      writeReturnType(node.returnType);
      write(' ${name}(');
      visitArguments(node.arguments);
      writeln(') {');
      write('    Object rawData = ${name}_raw(');
      bool first = true;
      for (int i = 0; i < node.arguments.length; i++) {
        if (first) {
          first = false;
        } else {
          write(', ');
        }
        write(node.arguments[i].name);
      }
      writeln(');');
      writeln('    if (rawData instanceof byte[]) {');
      write('      return new ');
      writeReturnType(node.returnType);
      writeln('((byte[])rawData);');
      writeln('    }');
      write('    return new ');
      writeReturnType(node.returnType);
      writeln('((byte[][])rawData);');
      writeln('  }');
    }
  }

  visitArguments(List<Formal> formals) {
    visitNodes(formals, (first) => first ? '' : ', ');
  }

  visitFormal(Formal node) {
    writeType(node.type);
    write(' ${node.name}');
  }

  visitStruct(Struct node) {
    writeReader(node);
    writeBuilder(node);
  }

  void writeReader(Struct node) {
    String fletchDirectory = join(outputDirectory, 'java', 'fletch');
    String name = node.name;
    StructLayout layout = node.layout;

    writeln('import fletch.$name;');

    StringBuffer buffer = new StringBuffer(HEADER);
    buffer.writeln();
    buffer.writeln(READER_HEADER);

    buffer.writeln('public class $name extends Reader {');
    buffer.writeln('  public $name(byte[] memory) {');
    buffer.writeln('    super(memory);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  public $name(byte[][] segments) {');
    buffer.writeln('    super(segments);');
    buffer.writeln('  }');
    buffer.writeln();

    for (StructSlot slot in layout.slots) {
      Type slotType = slot.slot.type;
      String camel = camelize(slot.slot.name);

      if (slot.isUnionSlot) {
        String tagName = camelize(slot.union.tag.name);
        int tag = slot.unionTag;
        buffer.writeln('  boolean is$camel() { return $tag == get$tagName(); }');
      }

      if (slotType.isList) {
        // TODO(ager): implement.
      } else if (slotType.isVoid) {
        // No getters for void slots.
      } else if (slotType.isPrimitive) {
        buffer.write('  public ');
        writeTypeToBuffer(slotType, buffer);
        buffer.write(' get$camel() { return get');
        buffer.write(camelize(getReturnType(slotType)));
        buffer.writeln('At(${slot.offset}); }');
      } else {
        // TODO(ager): implement.
      }
    }

    buffer.writeln('}');

    writeToFile(fletchDirectory, '$name', buffer.toString(),
                extension: 'java');
  }

  void writeBuilder(Struct node) {
    String fletchDirectory = join(outputDirectory, 'java', 'fletch');
    String name = '${node.name}Builder';

    writeln('import fletch.$name;');

    StringBuffer buffer = new StringBuffer(HEADER);
    buffer.writeln();
    buffer.writeln(READER_HEADER);

    buffer.writeln('class $name {');
    buffer.writeln('}');

    writeToFile(fletchDirectory, '$name', buffer.toString(),
                extension: 'java');
  }
}

class _JniVisitor extends CcVisitor {
  static const int REQUEST_HEADER_SIZE = 48;
  static const int RESPONSE_HEADER_SIZE = 8;  

  int methodId = 1;
  String serviceName;

  _JniVisitor(String path) : super(path);

  visitUnit(Unit node) {
    writeln(HEADER);
    writeln('#include <jni.h>');
    writeln('#include <stdlib.h>');
    writeln();
    writeln('#include "service_api.h"');
    node.services.forEach(visit);
  }

  visitService(Service node) {
    serviceName = node.name;

    writeln();

    writeln('#ifdef __cplusplus');
    writeln('extern "C" {');
    writeln('#endif');

    // TODO(ager): Get rid of this if we can. For some reason
    // the jni.h header that is used by the NDK differs.
    writeln();
    writeln('#ifdef ANDROID');
    writeln('  typedef JNIEnv* AttachEnvType;');
    writeln('#else');
    writeln('  typedef void* AttachEnvType;');
    writeln('#endif');

    writeln();
    writeln('static ServiceId service_id_ = kNoServiceId;');

    writeln();
    write('JNIEXPORT void JNICALL Java_fletch_');
    writeln('${serviceName}_Setup(JNIEnv*, jclass) {');
    writeln('  service_id_ = ServiceApiLookup("$serviceName");');
    writeln('}');

    writeln();
    write('JNIEXPORT void JNICALL Java_fletch_');
    writeln('${serviceName}_TearDown(JNIEnv*, jclass) {');
    writeln('  ServiceApiTerminate(service_id_);');
    writeln('}');

    // TODO(ager): Put this in resources and copy as a file instead.
    writeln();
    writeln(JNI_UTILS);

    node.methods.forEach(visit);

    writeln();
    writeln('#ifdef __cplusplus');
    writeln('}');
    writeln('#endif');
  }

  visitMethod(Method node) {
    String name = node.name;
    String id = '_k${name}Id';

    writeln();
    write('static const MethodId $id = ');
    writeln('reinterpret_cast<MethodId>(${methodId++});');

    if (node.inputKind != InputKind.PRIMITIVES) return;  // Not handled yet.

    writeln();
    write('JNIEXPORT ');
    writeReturnType(node.returnType);
    if (node.outputKind != OutputKind.PRIMITIVE) {
      write(' JNICALL Java_fletch_${serviceName}_${name}_1raw(');
    } else {
      write(' JNICALL Java_fletch_${serviceName}_${name}(');
    }
    write('JNIEnv* _env, jclass');
    if (!node.arguments.isEmpty) write(', ');
    visitArguments(node.arguments);
    writeln(') {');
    visitMethodBody(id, node);
    writeln('}');

    // TODO(ager): Support async variant with output structs.
    if (node.outputKind != OutputKind.PRIMITIVE) return;

    String callback = ensureCallback(node.returnType,
        node.inputPrimitiveStructLayout);

    writeln();
    write('JNIEXPORT void JNICALL ');
    write('Java_fletch_${serviceName}_${name}Async(');
    write('JNIEnv* _env, jclass');
    if (!node.arguments.isEmpty) write(', ');
    visitArguments(node.arguments);
    writeln(', jobject _callback) {');
    writeln('  jobject callback = _env->NewGlobalRef(_callback);');
    writeln('  JavaVM* vm;');
    writeln('  _env->GetJavaVM(&vm);');
    visitMethodBody(id,
                    node,
                    extraArguments: [ 'vm' ],
                    callback: callback);
    writeln('}');
  }

  visitMethodBody(String id,
                  Method method,
                  {bool cStyle: false,
                   List<String> extraArguments: const [],
                   String callback}) {
    List<Formal> arguments = method.arguments;
    assert(method.inputKind == InputKind.PRIMITIVES);
    StructLayout layout = method.inputPrimitiveStructLayout;
    final bool async = callback != null;
    int size = REQUEST_HEADER_SIZE + layout.size;
    if (async) {
      write('  static const int kSize = ');
      writeln('${size} + ${extraArguments.length} * sizeof(void*);');
    } else {
      writeln('  static const int kSize = ${size};');
    }

    String cast(String type) => CcVisitor.cast(type, cStyle);

    String pointerToArgument(int offset, int pointers, String type) {
      offset += REQUEST_HEADER_SIZE;
      String prefix = cast('$type*');
      if (pointers == 0) return '$prefix(_buffer + $offset)';
      return '$prefix(_buffer + $offset + $pointers * sizeof(void*))';
   }

    if (async) {
      writeln('  char* _buffer = ${cast("char*")}(malloc(kSize));');
    } else {
      writeln('  char _bits[kSize];');
      writeln('  char* _buffer = _bits;');
    }

    // Mark the message as being non-segmented.
    writeln('  *${pointerToArgument(-8, 0, "int64_t")} = 0;');

    int arity = arguments.length;
    for (int i = 0; i < arity; i++) {
      String name = arguments[i].name;
      int offset = layout[arguments[i]].offset;
      String type = PRIMITIVE_TYPES[arguments[i].type.identifier];
      writeln('  *${pointerToArgument(offset, 0, type)} = $name;');
    }

    if (async) {
      String dataArgument = pointerToArgument(-16, 0, 'void*');
      writeln('  *$dataArgument = ${cast("void*")}(callback);');
      for (int i = 0; i < extraArguments.length; i++) {
        String dataArgument = pointerToArgument(layout.size, i, 'void*');
        String arg = extraArguments[i];
        writeln('  *$dataArgument = ${cast("void*")}($arg);');
      }
      write('  ServiceApiInvokeAsync(service_id_, $id, $callback, ');
      writeln('_buffer, kSize);');
    } else {
      writeln('  ServiceApiInvoke(service_id_, $id, _buffer, kSize);');
      if (method.outputKind == OutputKind.STRUCT) {
        writeln('  int64_t result = *${pointerToArgument(0, 0, 'int64_t')};');
        writeln('  char* memory = reinterpret_cast<char*>(result);');
        // TODO(ajohnsen): Do range-check between size and segment size.
        writeln('  jobject rootSegment = getRootSegment(_env, memory);');
        writeln('  return rootSegment;');
      } else if (!method.returnType.isVoid) {
        writeln('  return *${pointerToArgument(0, 0, 'int64_t')};');
      }
    }
  }

  static const Map<String, String> PRIMITIVE_TYPES = const {
    'void' : 'void',
    'bool' : 'jboolean',

    'uint8' : 'jboolean',
    'uint16' : 'jchar',
    // TODO(ager): uint32 and uint64.

    'int8' : 'jbyte',
    'int16' : 'jshort',
    'int32' : 'jint',
    'int64' : 'jlong',

    'float32' : 'jfloat',
    'float64' : 'jdouble',
  };

  void writeType(Type node) {
    String type = PRIMITIVE_TYPES[node.identifier];
    write(type);
  }

  void writeReturnType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      write('jobject');
    } else {
      String type = PRIMITIVE_TYPES[node.identifier];
      write(type);
    }
  }

  final Map<String, String> callbacks = {};
  String ensureCallback(Type type,
                        StructLayout layout,
                        {bool cStyle: false}) {
    String key = '${type.identifier}_${layout.size}';
    return callbacks.putIfAbsent(key, () {
      String cast(String type) => CcVisitor.cast(type, cStyle);
      String name = 'Unwrap_$key';
      writeln();
      writeln('static void $name(void* raw) {');
      writeln('  char* buffer = ${cast('char*')}(raw);');
      if (!type.isVoid) {
        writeln('  int64_t result = *${cast('int64_t*')}(buffer + 48);');
      }
      int offset = 48 + layout.size;
      write('  jobject callback = *${cast('jobject*')}');
      writeln('(buffer + 32);');
      write('  JavaVM* vm = *${cast('JavaVM**')}');
      writeln('(buffer + $offset);');
      writeln('  JNIEnv* env = attachCurrentThreadAndGetEnv(vm);');
      writeln('  jclass clazz = env->GetObjectClass(callback);');
      write('  jmethodID methodId = env->GetMethodID');
      write('(clazz, "handle", ');
      if (type.isVoid) {
        writeln('"()V");');
        writeln('  env->CallVoidMethod(callback, methodId);');
      } else {
        writeln('"(I)V");');
        writeln('  env->CallVoidMethod(callback, methodId, result);');
      }
      writeln('  env->DeleteGlobalRef(callback);');
      writeln('  detachCurrentThread(vm);');
      writeln('  free(buffer);');
      writeln('}');
      return name;
    });
  }
}

void _generateServiceJniMakeFiles(String path, Unit unit, String outputDirectory) {
  String out = join(outputDirectory, 'java');
  String scriptFile = new File.fromUri(Platform.script).path;
  String scriptDir = dirname(scriptFile);
  String fletchLibraryBuildDir = join(scriptDir,
                                      '..',
                                      '..',
                                      'android_build',
                                      'jni');

  String fletchIncludeDir = join(scriptDir,
                                 '..',
                                 '..',
                                 '..',
                                 'include');

  String modulePath = relative(fletchLibraryBuildDir, from: out);
  String includePath = relative(fletchIncludeDir, from: out);

  StringBuffer buffer = new StringBuffer(HEADER_MK);

  buffer.writeln();
  buffer.writeln('LOCAL_PATH := \$(call my-dir)');

  buffer.writeln();
  buffer.writeln('include \$(CLEAR_VARS)');
  buffer.writeln('LOCAL_MODULE := fletch');
  buffer.writeln('LOCAL_CFLAGS := -DFLETCH32 -DANDROID');
  buffer.writeln('LOCAL_LDLIBS := -llog -ldl -rdynamic');

  buffer.writeln();
  buffer.writeln('LOCAL_SRC_FILES := \\');
  buffer.writeln('\tfletch_api_wrapper.cc \\');
  buffer.writeln('\tfletch_service_api_wrapper.cc \\');

  if (unit.services.length > 1) {
    print('Java plugin: multiple services in one file is not supported.');
  }
  String serviceName = unit.services.first.name;
  String file = '${strings.underscore(serviceName)}_wrapper';

  buffer.writeln('\t${file}.cc');

  buffer.writeln();
  buffer.writeln('LOCAL_C_INCLUDES += \$(LOCAL_PATH)');
  buffer.writeln('LOCAL_C_INCLUDES += ${includePath}');
  buffer.writeln('LOCAL_STATIC_LIBRARIES := fletch-library');

  buffer.writeln();
  buffer.writeln('include \$(BUILD_SHARED_LIBRARY)');

  buffer.writeln();
  buffer.writeln('\$(call import-module, ${modulePath})');

  writeToFile(join(out, 'jni'), 'Android', buffer.toString(),
      extension: 'mk');

  buffer = new StringBuffer(HEADER_MK);
  buffer.writeln('APP_STL := gnustl_static');
  buffer.writeln('APP_ABI := all');
  writeToFile(join(out, 'jni'), 'Application', buffer.toString(),
      extension: 'mk');

}
