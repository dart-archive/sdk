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
import '../primitives.dart' as primitives;

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
  public static native void WaitForDebuggerConnection(int port);
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

JNIEXPORT void JNICALL Java_fletch_FletchApi_WaitForDebuggerConnection(
    JNIEnv* env, jclass, int port) {
  FletchWaitForDebuggerConnection(port);
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

String JNI_UTILS = """
static JNIEnv* AttachCurrentThreadAndGetEnv(JavaVM* vm) {
  AttachEnvType result = NULL;
  if (vm->AttachCurrentThread(&result, NULL) != JNI_OK) {
    // TODO(ager): Nicer error recovery?
    exit(1);
  }
  return reinterpret_cast<JNIEnv*>(result);
}

static void DetachCurrentThread(JavaVM* vm) {
  if (vm->DetachCurrentThread() != JNI_OK) {
    // TODO(ager): Nicer error recovery?
    exit(1);
  }
}

static jobject CreateByteArray(JNIEnv* env, char* memory, int size) {
  jbyteArray result = env->NewByteArray(size);
  jbyte* contents = reinterpret_cast<jbyte*>(memory);
  env->SetByteArrayRegion(result, 0, size, contents);
  free(memory);
  return result;
}

static jobject CreateByteArrayArray(JNIEnv* env, char* memory, int size) {
  jobjectArray array = env->NewObjectArray(size, env->FindClass("[B"), NULL);
  for (int i = 0; i < size; i++) {
    int64_t address = *reinterpret_cast<int64_t*>(memory + 8 + (i * 16));
    int size = *reinterpret_cast<int*>(memory + 16 + (i * 16));
    char* contents = reinterpret_cast<char*>(address);
    env->SetObjectArrayElement(array, i, CreateByteArray(env, contents, size));
  }
  free(memory);
  return array;
}

static jobject GetRootSegment(JNIEnv* env, char* memory) {
  int32_t segments = *reinterpret_cast<int32_t*>(memory);
  if (segments == 0) {
    int32_t size = *reinterpret_cast<int32_t*>(memory + 4);
    return CreateByteArray(env, memory, size);
  }
  return CreateByteArrayArray(env, memory, segments);
}

class CallbackInfo {
 public:
  CallbackInfo(jobject jcallback, JavaVM* jvm)
      : callback(jcallback), vm(jvm) { }
  jobject callback;
  JavaVM* vm;
};

static char* ExtractByteArrayData(JNIEnv* env,
                                  jbyteArray segment,
                                  jint segment_length) {
  jbyte* data = env->GetByteArrayElements(segment, NULL);
  char* segment_copy = reinterpret_cast<char*>(malloc(segment_length));
  memcpy(segment_copy, data, segment_length);
  env->ReleaseByteArrayElements(segment, data, JNI_ABORT);
  return segment_copy;
}

static int ComputeMessage(JNIEnv* env,
                          jobject builder,
                          jobject callback,
                          JavaVM* vm,
                          char** buffer) {
  CallbackInfo* info = NULL;
  if (callback != NULL) {
    info = new CallbackInfo(callback, vm);
  }

  jclass clazz = env->GetObjectClass(builder);
  jmethodID method_id = env->GetMethodID(clazz, "getSegments", "()[Ljava/lang/Object;");
  jobjectArray array = (jobjectArray)env->CallObjectMethod(builder, method_id);
  jobjectArray segments = (jobjectArray)env->GetObjectArrayElement(array, 0);
  jintArray sizes_array = (jintArray)env->GetObjectArrayElement(array, 1);
  int* sizes = env->GetIntArrayElements(sizes_array, NULL);
  int number_of_segments = env->GetArrayLength(segments);

  if (number_of_segments > 1) {
    int size = $REQUEST_HEADER_SIZE + 8 + (number_of_segments * 16);
    *buffer = reinterpret_cast<char*>(malloc(size));
    int offset = $REQUEST_HEADER_SIZE + 8;
    for (int i = 0; i < number_of_segments; i++) {
      jbyteArray segment = (jbyteArray)env->GetObjectArrayElement(segments, i);
      jint segment_length = sizes[i];
      char* segment_copy = ExtractByteArrayData(env, segment, segment_length);
      *reinterpret_cast<void**>(*buffer + offset) = segment_copy;
      *reinterpret_cast<int*>(*buffer + offset + 8) = segment_length;
      offset += 16;
    }

    env->ReleaseIntArrayElements(sizes_array, sizes, JNI_ABORT);
    // Mark the request as being segmented.
    *${pointerToArgument('*buffer', -8, 'int64_t')} = number_of_segments;
    // Set the callback information.
    *${pointerToArgument('*buffer', -16, 'CallbackInfo*')} = info;
    return size;
  }

  jbyteArray segment = (jbyteArray)env->GetObjectArrayElement(segments, 0);
  jint segment_length = sizes[0];
  *buffer = ExtractByteArrayData(env, segment, segment_length);
  env->ReleaseIntArrayElements(sizes_array, sizes, JNI_ABORT);
  // Mark the request as being non-segmented.
  *${pointerToArgument('*buffer', -8, 'int64_t')} = 0;
  // Set the callback information.
  *${pointerToArgument('*buffer', -16, 'CallbackInfo*')} = info;
  return segment_length;
}

static void DeleteMessage(char* message) {
  int32_t segments = *${pointerToArgument('message', -8, 'int32_t')};
  for (int i = 0; i < segments; i++) {
    int64_t address = *reinterpret_cast<int64_t*>(message + ${REQUEST_HEADER_SIZE + 8} + (i * 16));
    char* memory = reinterpret_cast<char*>(address);
    free(memory);
  }
  free(message);
}""";

const int REQUEST_HEADER_SIZE = 56;

String pointerToArgument(String buffer, int offset, String type) {
  offset += REQUEST_HEADER_SIZE;
  return 'reinterpret_cast<$type*>($buffer + $offset)';
}

const List<String> JAVA_RESOURCES = const [
  "Builder.java",
  "BuilderSegment.java",
  "ListBuilder.java",
  "ListReader.java",
  "MessageBuilder.java",
  "MessageReader.java",
  "Reader.java",
  "Segment.java"
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
  final Set<Type> neededListTypes;
  final String outputDirectory;

  static Map<String, String> _GETTERS = const {
    'bool'    : 'segment.getBoolean',

    'uint8'   : 'segment.getUnsigned',
    'uint16'  : 'segment.getUnsignedChar',

    'int8'    : 'segment.buffer().get',
    'int16'   : 'segment.buffer().getShort',
    'int32'   : 'segment.buffer().getInt',
    'int64'   : 'segment.buffer().getLong',

    'float32' : 'segment.buffer().getFloat',
    'float64' : 'segment.buffer().getDouble',
  };

  static Map<String, String> _SETTERS = const {
    'bool'    : 'segment.buffer().put',

    'uint8'   : 'segment.buffer().put',
    'uint16'  : 'segment.buffer().putChar',

    'int8'    : 'segment.buffer().put',
    'int16'   : 'segment.buffer().putShort',
    'int32'   : 'segment.buffer().putInt',
    'int64'   : 'segment.buffer().putLong',

    'float32' : 'segment.buffer().putFloat',
    'float64' : 'segment.buffer().pubDouble',
  };

  static Map<String, String> _SETTER_TYPES = const {
    'bool'     : 'byte',

    'uint8'    : 'byte',
    'uint16'   : 'char',

    'int8'     : 'byte',
    'int16'    : 'char',
    'int32'    : 'int',
    'int64'    : 'long',

    'float32'  : 'float',
    'float64'  : 'double',
  };

  _JavaVisitor(String path, String this.outputDirectory)
    : neededListTypes = new Set<Type>(),
      super(path);

  static const PRIMITIVE_TYPES = const <String, String> {
    'void'    : 'void',
    'bool'    : 'boolean',

    'uint8'   : 'int',
    'uint16'  : 'int',

    'int8'    : 'int',
    'int16'   : 'int',
    'int32'   : 'int',
    'int64'   : 'long',

    'float32' : 'float',
    'float64' : 'double',
  };

  static const PRIMITIVE_LIST_TYPES = const <String, String> {
    'bool'    : 'boolean',

    'uint8'   : 'int',
    'uint16'  : 'int',

    'int8'    : 'int',
    'int16'   : 'int',
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

  String getListType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      return '${node.identifier}';
    } else {
      String type = PRIMITIVE_LIST_TYPES[node.identifier];
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

  void writeListTypeToBuffer(Type node, StringBuffer buffer) {
    buffer.write(getListType(node));
  }

  visitUnit(Unit node) {
    writeln(HEADER);
    writeln('package fletch;');
    writeln();
    node.structs.forEach(visit);
    node.services.forEach(visit);
    neededListTypes.forEach(writeListReaderImplementation);
    neededListTypes.forEach(writeListBuilderImplementation);
  }

  visitService(Service node) {
    writeln('public class ${node.name} {');
    writeln('  public static native void Setup();');
    writeln('  public static native void TearDown();');
    node.methods.forEach(visit);
    writeln('}');
  }

  visitMethod(Method node) {
    String name = node.name;
    String camelName = name.substring(0, 1).toUpperCase() + name.substring(1);
    writeln();
    writeln('  public static abstract class ${camelName}Callback {');
    if (!node.returnType.isVoid) {
      write('    public final java.lang.Class returnType = ');
      writeReturnType(node.returnType);
      writeln('.class;');
    }
    write('    public abstract void handle(');
    if (!node.returnType.isVoid) {
      writeReturnType(node.returnType);
      write(' result');
    }
    writeln(');');
    writeln('  }');

    writeln();
    write('  public static native ');
    writeReturnType(node.returnType);
    write(' $name(');
    visitArguments(node.arguments);
    writeln(');');
    write('  public static native void ${name}Async(');
    visitArguments(node.arguments);
    if (!node.arguments.isEmpty) write(', ');
    writeln('${camelName}Callback callback);');
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

    StringBuffer buffer = new StringBuffer(HEADER);
    buffer.writeln();
    buffer.writeln(READER_HEADER);

    buffer.writeln('import java.util.List;');
    buffer.writeln();

    buffer.writeln('public class $name extends Reader {');
    buffer.writeln('  public $name() { }');
    buffer.writeln();
    buffer.writeln('  public $name(byte[] memory, int offset) {');
    buffer.writeln('    super(memory, offset);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  public $name(Segment segment, int offset) {');
    buffer.writeln('    super(segment, offset);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  public $name(byte[][] segments, int offset) {');
    buffer.writeln('    super(segments, offset);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  public static $name create(Object rawData) {');
    buffer.writeln('    if (rawData instanceof byte[]) {');
    buffer.writeln('      return new $name((byte[])rawData, 8);');
    buffer.writeln('    }');
    buffer.writeln('    return new $name((byte[][])rawData, 8);');
    buffer.writeln('  }');

    for (StructSlot slot in layout.slots) {
      buffer.writeln();
      Type slotType = slot.slot.type;
      String camel = camelize(slot.slot.name);

      if (slot.isUnionSlot) {
        String tagName = camelize(slot.union.tag.name);
        int tag = slot.unionTag;
        buffer.writeln(
            '  public boolean is$camel() { return $tag == get$tagName(); }');
      }

      if (slotType.isList) {
        neededListTypes.add(slotType);
        String list = '${camelize(slotType.identifier)}List';
        buffer.writeln('  public $list get$camel() {');
        buffer.writeln('    ListReader reader = new ListReader();');
        buffer.writeln('    readList(reader, ${slot.offset});');
        buffer.writeln('    return new $list(reader);');
        buffer.writeln('  }');
      } else if (slotType.isVoid) {
        // No getters for void slots.
      } else if (slotType.isString) {
        buffer.write('  public String get$camel() { ');
        buffer.writeln('return readString(${slot.offset}); }');
        // TODO(ager): This is nasty. Maybe inject this type earler in the
        // pipeline?
        Type uint16ListType = new ListType(new SimpleType("uint16", false));
        uint16ListType.primitiveType = primitives.lookup("uint16");
        neededListTypes.add(uint16ListType);
        buffer.writeln('  public Uint16List get${camel}Data() {');
        buffer.writeln('    ListReader reader = new ListReader();');
        buffer.writeln('    readList(reader, ${slot.offset});');
        buffer.writeln('    return new Uint16List(reader);');
        buffer.writeln('  }');
      } else if (slotType.isPrimitive) {
        // TODO(ager): Dealing with unsigned numbers in Java is annoying.
        if (camel == 'Tag') {
          String getter = 'getUnsigned';
          String offset = 'base + ${slot.offset}';
          buffer.writeln('  public int getTag() {');
          buffer.writeln('    short shortTag = segment.$getter($offset);');
          buffer.writeln('    int tag = (int)shortTag;');
          buffer.writeln('    return tag < 0 ? -tag : tag;');
          buffer.writeln('  }');
        } else {
          String getter = _GETTERS[slotType.identifier];
          String offset = "base + ${slot.offset}";
          buffer.write('  public ${getType(slotType)} get$camel() { ');
          buffer.writeln('return $getter($offset); }');
        }
      } else {
        String returnType = getReturnType(slotType);
        buffer.write('  public $returnType get$camel() {');
        if (!slotType.isPointer) {
          String offset = 'base + ${slot.offset}';
          buffer.writeln(' return new $returnType(segment, $offset); }');
        } else {
          buffer.writeln();
          int offset = slot.offset;
          buffer.writeln('    $returnType reader = new $returnType();');
          buffer.writeln('    return ($returnType)readStruct(reader, $offset);');
          buffer.writeln('  }');
        }
      }
    }

    buffer.writeln('}');

    writeToFile(fletchDirectory, '$name', buffer.toString(),
                extension: 'java');
  }

  void writeBuilder(Struct node) {
    String fletchDirectory = join(outputDirectory, 'java', 'fletch');
    String name = '${node.name}Builder';
    StructLayout layout = node.layout;

    StringBuffer buffer = new StringBuffer(HEADER);
    buffer.writeln();
    buffer.writeln(READER_HEADER);

    buffer.write('import java.util.List;');
    buffer.writeln();
    buffer.writeln('public class $name extends Builder {');
    buffer.writeln('  public static int kSize = ${layout.size};');
    buffer.writeln('  public $name(BuilderSegment segment, int offset) {');
    buffer.writeln('    super(segment, offset);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  public $name() {');
    buffer.writeln('    super();');
    buffer.writeln('  }');

    for (StructSlot slot in layout.slots) {
      buffer.writeln();
      String slotName = slot.slot.name;
      String camel = camelize(slotName);
      Type slotType = slot.slot.type;

      String updateTag = '';
      if (slot.isUnionSlot) {
        String tagName = camelize(slot.union.tag.name);
        int tag = slot.unionTag;
        updateTag = '    set$tagName($tag);\n';
      }

      if (slotType.isList) {
        String listBuilder = '';
        if (slotType.isPrimitive) {
          listBuilder =  '${camelize(slotType.identifier)}ListBuilder';
        } else {
          listBuilder = '${getListType(slotType)}ListBuilder';
        }
        buffer.writeln('  public $listBuilder init$camel(int length) {');
        buffer.write(updateTag);
        int size = 0;
        if (slotType.isPrimitive) {
          size = primitives.size(slotType.primitiveType);
        } else {
          Struct element = slotType.resolved;
          StructLayout elementLayout = element.layout;
          size = elementLayout.size;
        }
        buffer.writeln('    ListBuilder builder = new ListBuilder();');
        buffer.writeln('    newList(builder, ${slot.offset}, length, $size);');
        buffer.writeln('    return new ${listBuilder}(builder);');
        buffer.writeln('  }');
      } else if (slotType.isVoid) {
        assert(slot.isUnionSlot);
        String tagName = camelize(slot.union.tag.name);
        int tag = slot.unionTag;
        buffer.writeln('  public void set$camel() {'
                       ' set$tagName($tag); }');
      } else if (slotType.isString) {
        buffer.writeln('  public void set$camel(String value) {');
        buffer.write(updateTag);
        buffer.writeln('    newString(${slot.offset}, value);');
        buffer.writeln('  }');
        buffer.writeln();
        buffer.writeln('  public Uint16ListBuilder init${camel}Data(int length) {');
        buffer.write(updateTag);
        buffer.writeln('    ListBuilder builder = new ListBuilder();');
        buffer.writeln('    newList(builder, ${slot.offset}, length, 2);');
        buffer.writeln('    return new Uint16ListBuilder(builder);');
        buffer.writeln('  }');
      } else if (slotType.isPrimitive) {
        String setter = _SETTERS[slotType.identifier];
        String setterType = _SETTER_TYPES[slotType.identifier];
        String offset = 'base + ${slot.offset}';
        buffer.writeln('  public void set$camel(${getType(slotType)} value) {');
        buffer.write(updateTag);
        if (slotType.isBool) {
          buffer.writeln('    $setter($offset,'
                         ' (byte)(value ? 1 : 0));');
        } else {
          buffer.writeln('    $setter($offset, (${setterType})value);');
        }
        buffer.writeln('  }');
      } else {
        buffer.writeln('  public ${getType(slotType)} init$camel() {');
        buffer.write(updateTag);
        String builderType = getType(slotType);
        if (!slotType.isPointer) {
          buffer.writeln('    $builderType result = new $builderType();');
          buffer.writeln('    result.segment = segment;');
          buffer.writeln('    result.base = base + ${slot.offset};');
          buffer.writeln('    return result;');
        } else {
          Struct element = slotType.resolved;
          StructLayout elementLayout = element.layout;
          int size = elementLayout.size;
          buffer.writeln('    $builderType result = new $builderType();');
          buffer.writeln('    newStruct(result, ${slot.offset}, $size);');
          buffer.writeln('    return result;');
        }
        buffer.writeln('  }');
      }
    }

    buffer.writeln('}');

    writeToFile(fletchDirectory, '$name', buffer.toString(),
                extension: 'java');
  }

  void writeListReaderImplementation(Type type) {
    String fletchDirectory = join(outputDirectory, 'java', 'fletch');
    String name = '${camelize(type.identifier)}List';
    String listType = getListType(type);

    StringBuffer buffer = new StringBuffer(HEADER);
    buffer.writeln();
    buffer.writeln(READER_HEADER);

    buffer.writeln('public class $name {');
    if (type.isPrimitive) {
      int elementSize = primitives.size(type.primitiveType);
      String offset = 'reader.base + index * $elementSize';

      buffer.writeln('  private ListReader reader;');
      buffer.writeln();
      buffer.writeln('  public $name(ListReader reader) {'
                     ' this.reader = reader; }');
      buffer.writeln();
      buffer.writeln('  public $listType get(int index) {');
      buffer.write('    return ');
      buffer.writeln('reader.${_GETTERS[type.identifier]}($offset);');
      buffer.writeln('  }');
    } else {
      Struct element = type.resolved;
      StructLayout elementLayout = element.layout;;
      int elementSize = elementLayout.size;
      String returnType = getReturnType(type);

      buffer.writeln('  private ListReader reader;');
      buffer.writeln();
      buffer.writeln('  public $name(ListReader reader) {'
                     ' this.reader = reader; }');
      buffer.writeln();
      buffer.writeln('  public $returnType get(int index) {');
      buffer.writeln('    $returnType result = new $returnType();');
      buffer.writeln('    reader.readListElement('
                     'result, index, $elementSize);');
      buffer.writeln('    return result;');
      buffer.writeln('  }');
    }

    buffer.writeln();
    buffer.writeln('  public int size() { return reader.length; }');

    buffer.writeln('}');

    writeToFile(fletchDirectory, '$name', buffer.toString(),
                extension: 'java');
  }

  void writeListBuilderImplementation(Type type) {
    String fletchDirectory = join(outputDirectory, 'java', 'fletch');
    String name = '${camelize(type.identifier)}ListBuilder';

    StringBuffer buffer = new StringBuffer(HEADER);
    buffer.writeln();
    buffer.writeln(READER_HEADER);

    buffer.writeln('public class $name {');
    buffer.writeln('  private ListBuilder builder;');
    buffer.writeln();
    buffer.writeln('  public $name(ListBuilder builder) {'
                   ' this.builder = builder; }');
    buffer.writeln();

    if (type.isPrimitive) {
      int elementSize = primitives.size(type.primitiveType);
      String offset = 'builder.base + index * $elementSize';
      String listType = getListType(type);
      String getter = _GETTERS[type.identifier];

      buffer.writeln('  public $listType get(int index) {');
      buffer.writeln('    return builder.$getter($offset);');
      buffer.writeln('  }');

      buffer.writeln();
      String setter = _SETTERS[type.identifier];
      String setterType = _SETTER_TYPES[type.identifier];
      buffer.writeln('  public $listType set(int index, $listType value) {');
      buffer.write('    builder.$setter($offset, (${setterType})value);');
      buffer.writeln('    return value;');
      buffer.writeln('  }');
    } else {
      Struct element = type.resolved;
      StructLayout elementLayout = element.layout;;
      int elementSize = elementLayout.size;
      String structType = getType(type);

      buffer.writeln('  public $structType get(int index) {');
      buffer.writeln('    $structType result = new $structType();');
      buffer.writeln('    builder.readListElement('
                     'result, index, $elementSize);');
      buffer.writeln('    return result;');
      buffer.writeln('  }');
    }

    buffer.writeln();
    buffer.writeln('  public int size() { return builder.length; }');

    buffer.writeln('}');

    writeToFile(fletchDirectory, '$name', buffer.toString(),
                extension: 'java');
  }
}

class _JniVisitor extends CcVisitor {
  static const int REQUEST_HEADER_SIZE = 48 + 8;
  static const int RESPONSE_HEADER_SIZE = 8;

  int methodId = 1;
  String serviceName;

  _JniVisitor(String path) : super(path);

  visitUnit(Unit node) {
    writeln(HEADER);
    writeln('#include <jni.h>');
    writeln('#include <stdlib.h>');
    writeln('#include <string.h>');
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

    writeln();
    write('JNIEXPORT ');
    writeReturnType(node.returnType);
    write(' JNICALL Java_fletch_${serviceName}_${name}(');
    write('JNIEnv* _env, jclass');
    if (!node.arguments.isEmpty) write(', ');
    if (node.inputKind != InputKind.PRIMITIVES) {
      write('jobject ${node.arguments.single.name}');
    } else {
      visitArguments(node.arguments);
    }
    writeln(') {');
    if (node.inputKind != InputKind.PRIMITIVES) {
      visitStructArgumentMethodBody(id, node);
    } else {
      visitMethodBody(id, node);
    }
    writeln('}');

    String callback;
    if (node.inputKind == InputKind.STRUCT) {
      StructLayout layout = node.arguments.single.type.resolved.layout;
      callback = ensureCallback(node.returnType, layout);
    } else {
      callback =
          ensureCallback(node.returnType, node.inputPrimitiveStructLayout);
    }

    writeln();
    write('JNIEXPORT void JNICALL ');
    write('Java_fletch_${serviceName}_${name}Async(');
    write('JNIEnv* _env, jclass');
    if (!node.arguments.isEmpty) write(', ');
    if (node.inputKind != InputKind.PRIMITIVES) {
      write('jobject ${node.arguments.single.name}');
    } else {
      visitArguments(node.arguments);
    }
    writeln(', jobject _callback) {');
    writeln('  jobject callback = NULL;');
    writeln('  JavaVM* vm = NULL;');
    writeln('  if (_callback) {');
    writeln('    callback = _env->NewGlobalRef(_callback);');
    writeln('    _env->GetJavaVM(&vm);');
    writeln('  }');
    // TODO(zerny): Issue #45. Store VM pointer in 'callback data' header field.
    if (node.inputKind != InputKind.PRIMITIVES) {
      visitStructArgumentMethodBody(id,
                                    node,
                                    extraArguments: [ 'vm' ],
                                    callback: callback);
    } else {
      visitMethodBody(id,
                      node,
                      extraArguments: [ 'vm' ],
                      callback: callback);
    }
    writeln('}');
  }

  visitMethodBody(String id,
                  Method method,
                  {bool cStyle: false,
                   List<String> extraArguments: const [],
                   String callback}) {
    String cast(String type) => CcVisitor.cast(type, false);

    String pointerToArgument(int offset, int pointers, String type) {
      offset += REQUEST_HEADER_SIZE;
      String prefix = cast('$type*');
      if (pointers == 0) return '$prefix(_buffer + $offset)';
      return '$prefix(_buffer + $offset + $pointers * sizeof(void*))';
    }

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
      writeln('  CallbackInfo* info = callback ? new CallbackInfo(callback, vm) : NULL;');
      writeln('  *${pointerToArgument(-16, 0, "CallbackInfo*")} = info;');
      write('  ServiceApiInvokeAsync(service_id_, $id, $callback, ');
      writeln('_buffer, kSize);');
    } else {
      writeln('  ServiceApiInvoke(service_id_, $id, _buffer, kSize);');
      if (method.outputKind == OutputKind.STRUCT) {
        Type type = method.returnType;
        writeln('  int64_t result = *${pointerToArgument(0, 0, 'int64_t')};');
        writeln('  char* memory = reinterpret_cast<char*>(result);');
        writeln('  jobject rootSegment = GetRootSegment(_env, memory);');
        writeln('  jclass resultClass = '
                '_env->FindClass("fletch/${type.identifier}");');
        writeln('  jmethodID create = _env->GetStaticMethodID('
                'resultClass, "create", '
                '"(Ljava/lang/Object;)Lfletch/${type.identifier};");');
        writeln('  jobject resultObject = _env->CallStaticObjectMethod('
                'resultClass, create, rootSegment);');
        writeln('  return resultObject;');
      } else if (!method.returnType.isVoid) {
        writeln('  return *${pointerToArgument(0, 0, 'int64_t')};');
      }
    }
  }

  visitStructArgumentMethodBody(String id,
                                Method method,
                                {bool cStyle: false,
                                 List<String> extraArguments: const [],
                                 String callback}) {
    String cast(String type) => CcVisitor.cast(type, false);

    String pointerToArgument(int offset, int pointers, String type) {
      offset += REQUEST_HEADER_SIZE;
      String prefix = cast('$type*');
      if (pointers == 0) return '$prefix(buffer + $offset)';
      return '$prefix(buffer + $offset + $pointers * sizeof(void*))';
    }

    String argumentName = method.arguments.single.name;

    bool async = callback != null;
    String javaCallback = async ? 'callback' : 'NULL';
    String javaVM = async ? 'vm' : 'NULL';

    writeln('  char* buffer = NULL;');
    writeln('  int size = ComputeMessage('
            '_env, $argumentName, $javaCallback, $javaVM, &buffer);');

    if (async) {
      write('  ServiceApiInvokeAsync(service_id_, $id, $callback, ');
      writeln('buffer, size);');
    } else {
      writeln('  ServiceApiInvoke(service_id_, $id, buffer, size);');
      writeln('  int64_t result = *${pointerToArgument(0, 0, 'int64_t')};');
      writeln('  DeleteMessage(buffer);');
      if (method.outputKind == OutputKind.STRUCT) {
        Type type = method.returnType;
        writeln('  char* memory = reinterpret_cast<char*>(result);');
        writeln('  jobject rootSegment = GetRootSegment(_env, memory);');
        writeln('  jclass resultClass = '
                '_env->FindClass("fletch/${type.identifier}");');
        writeln('  jmethodID create = _env->GetStaticMethodID('
                'resultClass, "create", '
                '"(Ljava/lang/Object;)Lfletch/${type.identifier};");');
        writeln('  jobject resultObject = _env->CallStaticObjectMethod('
                'resultClass, create, rootSegment);');
        writeln('  return resultObject;');
      } else {
        if (!method.returnType.isVoid) writeln('  return result;');
      }
    }
  }

  static const Map<String, String> PRIMITIVE_TYPES = const {
    'void' : 'void',
    'bool' : 'jboolean',

    'uint8' : 'jboolean',
    'uint16' : 'jchar',

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

  static const Map<String, String> PRIMITIVE_JNI_SIG = const {
    'void' : '',
    'bool' : 'Z',

    'uint8' : 'Z',
    'uint16' : 'C',

    'int8' : 'B',
    'int16' : 'S',
    'int32' : 'I',
    'int64' : 'J',

    'float32' : 'F',
    'float64' : 'D',
  };

  String getJNISignatureType(Type type) {
    String name = type.identifier;
    if (type.isPrimitive) return PRIMITIVE_JNI_SIG[name];
    return 'Lfletch/$name;';
  }

  final Map<String, String> callbacks = {};
  String ensureCallback(Type type,
                        StructLayout layout,
                        {bool cStyle: false}) {
    String key = '${type.identifier}_${layout.size}';
    return callbacks.putIfAbsent(key, () {
      String cast(String type) => CcVisitor.cast(type, cStyle);
      String pointerToArgument(int offset, String type) {
        offset += REQUEST_HEADER_SIZE;
        String prefix = cast('$type*');
        return '$prefix(buffer + $offset)';
      }
      String name = 'Unwrap_$key';
      writeln();
      writeln('static void $name(void* raw) {');
      writeln('  char* buffer = ${cast('char*')}(raw);');
      write('  CallbackInfo* info =');
      writeln(' *${pointerToArgument(-16, "CallbackInfo*")};');
      writeln('  if (info == NULL) return;');
      writeln('  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);');
      writeln('  jclass clazz = env->GetObjectClass(info->callback);');
      if (!type.isVoid) {
        write('  int64_t result =');
        writeln(' *${pointerToArgument(0, 'int64_t')};');
        writeln('  DeleteMessage(buffer);');
        if (!type.isPrimitive) {
          writeln('  char* memory = reinterpret_cast<char*>(result);');
          writeln('  jobject rootSegment = GetRootSegment(env, memory);');
          write('  jfieldID returnTypeField = env->GetFieldID(');
          writeln('clazz, "returnType", "Ljava/lang/Class;");');
          write('  jclass resultClass = (jclass)');
          writeln('env->GetObjectField(info->callback, returnTypeField);');
          writeln('  jmethodID create = env->GetStaticMethodID('
                  'resultClass, "create", '
                  '"(Ljava/lang/Object;)Lfletch/${type.identifier};");');
          writeln('  jobject resultObject = env->CallStaticObjectMethod('
                  'resultClass, create, rootSegment);');
        }
      } else {
        writeln('  DeleteMessage(buffer);');
      }
      write('  jmethodID methodId = env->GetMethodID');
      write('(clazz, "handle", ');
      if (type.isVoid) {
        writeln('"()V");');
        writeln('  env->CallVoidMethod(info->callback, methodId);');
      } else {
        String signatureType = getJNISignatureType(type);
        writeln('"($signatureType)V");');
        write('  env->CallVoidMethod(info->callback, methodId,');
        if (!type.isPrimitive) {
          writeln(' resultObject);');
        } else {
          writeln(' result);');
        }
      }
      writeln('  env->DeleteGlobalRef(info->callback);');
      writeln('  DetachCurrentThread(info->vm);');
      writeln('  delete info;');
      writeln('}');
      return name;
    });
  }
}

void _generateServiceJniMakeFiles(String path,
                                  Unit unit,
                                  String outputDirectory) {
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
  buffer.writeln('APP_ABI := x86 armeabi-v7a');
  // TODO(zerny): Is this the right place and way to ensure ABI >= 8?
  buffer.writeln('APP_PLATFORM := android-8');
  writeToFile(join(out, 'jni'), 'Application', buffer.toString(),
      extension: 'mk');

}
