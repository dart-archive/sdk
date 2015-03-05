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
    int64_t address = *reinterpret_cast<int64_t*>(memory + 8 + (i * 16));
    int size = *reinterpret_cast<int*>(memory + 16 + (i * 16));
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
  return createByteArrayArray(env, memory, segments);
}

class CallbackInfo {
 public:
  CallbackInfo(jobject jcallback, JavaVM* jvm)
      : callback(jcallback), vm(jvm) { }
  jobject callback;
  JavaVM* vm;
};

static int computeMessage(JNIEnv* env,
                          jobject builder,
                          char** buffer,
                          jobject callback,
                          JavaVM* vm) {
  jclass clazz = env->GetObjectClass(builder);
  jmethodID methodId = env->GetMethodID(clazz, "isSegmented", "()Z");
  jboolean isSegmented =  env->CallBooleanMethod(builder, methodId);

  CallbackInfo* info = NULL;
  if (callback != NULL) {
    info = new CallbackInfo(callback, vm);
  }

  if (isSegmented) {
    methodId = env->GetMethodID(clazz, "getSegments", "()[[B");
    jobjectArray array = (jobjectArray)env->CallObjectMethod(builder, methodId);
    int segments = env->GetArrayLength(array);

    int size = 56 + (segments * 16);
    *buffer = reinterpret_cast<char*>(malloc(size));
    int offset = 56;
    for (int i = 0; i < segments; i++) {
      jbyteArray segment = (jbyteArray)env->GetObjectArrayElement(array, i);
      int segment_length = env->GetArrayLength(segment);
      jboolean is_copy;
      jbyte* data = env->GetByteArrayElements(segment, &is_copy);
      // TODO(ager): Release this again.
      *reinterpret_cast<void**>(*buffer + offset) = data;
      // TODO(ager): Correct sizing.
      *reinterpret_cast<int*>(*buffer + offset + 8) = segment_length;
      offset += 16;
    }

    // Mark the request as being segmented.
    *reinterpret_cast<int32_t*>(*buffer + 40) = segments;
    // Set the callback information.
    *reinterpret_cast<CallbackInfo**>(*buffer + 32) = info;
    return size;
  }

  methodId = env->GetMethodID(clazz, "getSingleSegment", "()[B");
  jbyteArray segment = (jbyteArray)env->CallObjectMethod(builder, methodId);
  int segment_length = env->GetArrayLength(segment);
  jboolean is_copy;
  // TODO(ager): Release this again.
  jbyte* data = env->GetByteArrayElements(segment, &is_copy);
  *buffer = reinterpret_cast<char*>(data);
  // Mark the request as being non-segmented.
  *reinterpret_cast<int64_t*>(*buffer + 40) = 0;
  // Set the callback information.
  *reinterpret_cast<CallbackInfo**>(*buffer + 32) = info;
  // TODO(ager): Correct sizing.
  return segment_length;
}""";

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
    'bool'    : 'getBooleanAt',

    'uint8'   : 'getUnsignedByteAt',
    'uint16'  : 'getCharAt',
    'uint32'  : 'getUnsignedIntAt',
    // TODO(ager): consider how to deal with unsigned 64-bit integers.

    'int8'    : 'getByteAt',
    'int16'   : 'getShortAt',
    'int32'   : 'getIntAt',
    'int64'   : 'getLongAt',

    'float32' : 'getFloatAt',
    'float64' : 'getDoubleAt',
  };

  // TODO(ager): Unify the getter/setter names. Avoid extra indirections
  // for getters.
  static Map<String, String> _SETTERS = const {
    'bool'    : 'put',

    'uint8'   : 'put',
    'uint16'  : 'putChar',
    'uint32'  : 'putInt',
    // TODO(ager): consider how to deal with unsigned 64-bit integers.

    'int8'    : 'put',
    'int16'   : 'putShort',
    'int32'   : 'putInt',
    'int64'   : 'putLong',

    'float32' : 'putFloat',
    'float64' : 'pubDouble',
  };

  static Map<String, String> _SETTER_TYPES = const {
    'bool'    : 'byte',

    'uint8'   : 'byte',
    'uint16'  : 'char',
    'uint32'  : 'int',
    // TODO(ager): consider how to deal with unsigned 64-bit integers.

    'int8'    : 'byte',
    'int16'   : 'char',
    'int32'   : 'int',
    'int64'   : 'long',

    'float32' : 'float',
    'float64' : 'double',
  };

  _JavaVisitor(String path, String this.outputDirectory)
    : neededListTypes = new Set<Type>(),
      super(path);

  static const PRIMITIVE_TYPES = const <String, String> {
    'void'    : 'void',
    'bool'    : 'boolean',

    'uint8'   : 'short',
    'uint16'  : 'char',
    'uint32'  : 'long',
    // TODO(ager): consider how to deal with unsigned 64 bit integers.

    'int8'    : 'byte',
    'int16'   : 'short',
    'int32'   : 'int',
    'int64'   : 'long',

    'float32' : 'float',
    'float64' : 'double',
  };

  static const PRIMITIVE_LIST_TYPES = const <String, String> {
    'bool'    : 'Boolean',

    'uint8'   : 'Short',
    'uint16'  : 'Char',
    'uint32'  : 'Long',
    // TODO(ager): consider how to deal with unsigned 64 bit integers.

    'int8'    : 'Byte',
    'int16'   : 'Short',
    'int32'   : 'Integer',
    'int64'   : 'Long',

    'float32' : 'Float',
    'float64' : 'Double',
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
      Type slotType = slot.slot.type;
      String camel = camelize(slot.slot.name);

      if (slot.isUnionSlot) {
        String tagName = camelize(slot.union.tag.name);
        int tag = slot.unionTag;
        buffer.writeln();
        buffer.writeln('  public boolean is$camel() {'
                       ' return $tag == get$tagName(); }');
      }

      if (slotType.isList) {
        neededListTypes.add(slotType);
        buffer.writeln();
        buffer.write('  public List<');
        writeListTypeToBuffer(slotType, buffer);
        buffer.writeln('> get$camel() {');
        buffer.writeln('    ListReader reader = new ListReader();');
        buffer.writeln('    readList(reader, ${slot.offset});');
        buffer.write('    return new ');
        buffer.write(camelize(slotType.identifier));
        buffer.writeln('List(reader);');
        buffer.writeln('  }');
      } else if (slotType.isVoid) {
        // No getters for void slots.
      } else if (slotType.isPrimitive) {
        // TODO(ager): Dealing with unsigned numbers in Java is annoying.
        buffer.writeln();
        if (camel == 'Tag') {
          buffer.writeln('  public int getTag() {');
          buffer.writeln('    short shortTag = getShortAt(${slot.offset});');
          buffer.writeln('    int tag = (int)shortTag;');
          buffer.writeln('    return tag < 0 ? -tag : tag;');
          buffer.writeln('  }');
        } else {
          buffer.write('  public ');
          writeTypeToBuffer(slotType, buffer);
          buffer.write(' get$camel() { return get');
          buffer.write(camelize(getReturnType(slotType)));
          buffer.writeln('At(${slot.offset}); }');
        }
      } else {
        buffer.writeln();
        buffer.write('  public ');
        writeReturnTypeToBuffer(slotType, buffer);
        buffer.writeln(' get$camel() {');
        if (!slotType.isPointer) {
          buffer.write('    return new ');
          writeReturnTypeToBuffer(slotType, buffer);
          buffer.writeln('(segment, base + ${slot.offset});');
        } else {
          buffer.write('    ');
          writeReturnTypeToBuffer(slotType, buffer);
          buffer.write(' reader = new ');
          writeReturnTypeToBuffer(slotType, buffer);
          buffer.writeln('();');
          buffer.write('    return (');
          writeReturnTypeToBuffer(slotType, buffer);
          buffer.writeln(')readStruct(reader, ${slot.offset});');
        }
        buffer.writeln('  }');
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
        updateTag = '    set$tagName((char)$tag);\n';
      }

      if (slotType.isList) {
        String listElement = '';
        if (slotType.isPrimitive) {
          listElement = '${getListType(slotType)}';
        }  else {
          listElement = '${getListType(slotType)}Builder';
        }
        String listBuilder = '';
        if (slotType.isPrimitive) {
          listBuilder =  '${camelize(slotType.identifier)}ListBuilder';
        } else {
          listBuilder = '${getListType(slotType)}ListBuilder';
        }
        buffer.writeln('  public List<$listElement> init$camel(int length) {');
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
                       ' set$tagName((char)$tag); }');
      } else if (slotType.isPrimitive) {
        String setter = _SETTERS[slotType.identifier];
        String setterType = _SETTER_TYPES[slotType.identifier];
        String offset = 'base + ${slot.offset}';
        buffer.write('  public void set$camel(');
        writeTypeToBuffer(slotType, buffer);
        buffer.writeln(' value) {');
        buffer.write(updateTag);
        if (slotType.isBool) {
          buffer.writeln('    segment.buffer().$setter($offset,'
                         ' (byte)(value ? 1 : 0));');
        } else {
          buffer.writeln('    segment.buffer().'
                         '$setter($offset, (${setterType})value);');
        }
        buffer.writeln('  }');
      } else {
        buffer.write('  public ');
        writeTypeToBuffer(slotType, buffer);
        buffer.writeln(' init$camel() {');
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

    StringBuffer buffer = new StringBuffer(HEADER);
    buffer.writeln();
    buffer.writeln(READER_HEADER);

    buffer.writeln('import java.util.AbstractList;');

    buffer.writeln();
    buffer.write('class $name extends AbstractList<');
    writeListTypeToBuffer(type, buffer);
    buffer.writeln('> {');
    if (type.isPrimitive) {
      int elementSize = primitives.size(type.primitiveType);
      String offset = 'index * $elementSize';

      buffer.writeln('  private ListReader reader;');

      buffer.writeln();
      buffer.writeln('  public $name(ListReader reader) {'
                     ' this.reader = reader; }');

      buffer.writeln();
      buffer.write('  public ');
      writeListTypeToBuffer(type, buffer);
      buffer.writeln(' get(int index) {');
      buffer.write('    ');
      writeReturnTypeToBuffer(type, buffer);
      buffer.writeln(' result = reader.${_GETTERS[type.identifier]}($offset);');

      buffer.write('    return new ');
      writeListTypeToBuffer(type, buffer);
      buffer.writeln('(result);');
      buffer.writeln('  }');
    } else {
      Struct element = type.resolved;
      StructLayout elementLayout = element.layout;;
      int elementSize = elementLayout.size;

      buffer.writeln('  private ListReader reader;');

      buffer.writeln();
      buffer.writeln('  public $name(ListReader reader) {'
                     ' this.reader = reader; }');

      buffer.writeln();
      buffer.write('  public ');
      writeReturnTypeToBuffer(type, buffer);
      buffer.writeln(' get(int index) {');
      buffer.write('    ');
      writeReturnTypeToBuffer(type, buffer);
      buffer.write(' result = new ');
      writeReturnTypeToBuffer(type, buffer);
      buffer.writeln('();');
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

    buffer.writeln('import java.util.AbstractList;');

    if (type.isPrimitive) {
      int elementSize = primitives.size(type.primitiveType);
      String offset = 'index * $elementSize';

      buffer.writeln();
      buffer.write('class $name extends AbstractList<');
      writeListTypeToBuffer(type, buffer);
      buffer.writeln('> {');

      buffer.writeln('  private ListBuilder builder;');

      buffer.writeln();
      buffer.writeln('  public $name(ListBuilder builder) {'
                     ' this.builder = builder; }');

      buffer.writeln();
      buffer.write('  public ');
      writeListTypeToBuffer(type, buffer);
      buffer.writeln(' get(int index) {');
      buffer.write('    ');
      writeReturnTypeToBuffer(type, buffer);
      buffer.writeln(' result = '
                     'builder.${_GETTERS[type.identifier]}($offset);');

      buffer.write('    return new ');
      writeListTypeToBuffer(type, buffer);
      buffer.writeln('(result);');
      buffer.writeln('  }');

      buffer.writeln();
      String listType = getListType(type);
      String setter = _SETTERS[type.identifier];
      String setterType = _SETTER_TYPES[type.identifier];
      buffer.writeln('  public $listType set(int index, $listType value) {');
      buffer.write('    builder.segment().buffer().');
      buffer.writeln('$setter(builder.base + $offset, value.${setterType}Value());');
      buffer.writeln('    return value;');
      buffer.writeln('  }');
    } else {
      Struct element = type.resolved;
      StructLayout elementLayout = element.layout;;
      int elementSize = elementLayout.size;

      buffer.writeln();
      buffer.write('class $name extends AbstractList<');
      writeTypeToBuffer(type, buffer);
      buffer.writeln('> {');

      buffer.writeln('  private ListBuilder builder;');

      buffer.writeln();
      buffer.writeln('  public $name(ListBuilder builder) {'
                     ' this.builder = builder; }');

      buffer.writeln();
      buffer.write('  public ');
      writeTypeToBuffer(type, buffer);
      buffer.writeln(' get(int index) {');
      buffer.write('    ');
      writeTypeToBuffer(type, buffer);
      buffer.write(' result = new ');
      writeTypeToBuffer(type, buffer);
      buffer.writeln('();');
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
    writeln('  jobject callback = _env->NewGlobalRef(_callback);');
    writeln('  JavaVM* vm;');
    writeln('  _env->GetJavaVM(&vm);');
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
      writeln('  CallbackInfo* info = new CallbackInfo(callback, vm);');
      writeln('  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;');
      write('  ServiceApiInvokeAsync(service_id_, $id, $callback, ');
      writeln('_buffer, kSize);');
    } else {
      writeln('  ServiceApiInvoke(service_id_, $id, _buffer, kSize);');
      if (method.outputKind == OutputKind.STRUCT) {
        Type type = method.returnType;
        writeln('  int64_t result = *${pointerToArgument(0, 0, 'int64_t')};');
        writeln('  char* memory = reinterpret_cast<char*>(result);');
        writeln('  jobject rootSegment = getRootSegment(_env, memory);');
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

    StructLayout layout = method.arguments.single.type.resolved.layout;
    String argumentName = method.arguments.single.name;

    bool async = callback != null;
    String javaCallback = async ? 'callback' : 'NULL';
    String javaVM = async ? 'vm' : 'NULL';

    writeln('  char* buffer = NULL;');
    writeln('  int size = computeMessage('
            '_env, $argumentName, &buffer, $javaCallback, $javaVM);');

    if (async) {
      write('  ServiceApiInvokeAsync(service_id_, $id, $callback, ');
      writeln('buffer, size);');
    } else {
      writeln('  ServiceApiInvoke(service_id_, $id, buffer, size);');
      if (method.outputKind == OutputKind.STRUCT) {
        Type type = method.returnType;
        writeln('  int64_t result = *${pointerToArgument(0, 0, 'int64_t')};');
        writeln('  char* memory = reinterpret_cast<char*>(result);');
        writeln('  jobject rootSegment = getRootSegment(_env, memory);');
        writeln('  jclass resultClass = '
                '_env->FindClass("fletch/${type.identifier}");');
        writeln('  jmethodID create = _env->GetStaticMethodID('
                'resultClass, "create", '
                '"(Ljava/lang/Object;)Lfletch/${type.identifier};");');
        writeln('  jobject resultObject = _env->CallStaticObjectMethod('
                'resultClass, create, rootSegment);');
        writeln('  return resultObject;');
      } else {
        writeln('  return *reinterpret_cast<int64_t*>(buffer + 48);');
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

  static const Map<String, String> PRIMITIVE_JNI_SIG = const {
    'void' : '',
    'bool' : 'Z',

    'uint8' : 'Z',
    'uint16' : 'C',
    // TODO(ager): uint32 and uint64.

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
      String name = 'Unwrap_$key';
      writeln();
      writeln('static void $name(void* raw) {');
      writeln('  char* buffer = ${cast('char*')}(raw);');
      int offset = 48 + layout.size;
      write('  CallbackInfo* info = *${cast('CallbackInfo**')}');
      writeln('(buffer + 32);');
      writeln('  JNIEnv* env = attachCurrentThreadAndGetEnv(info->vm);');
      if (!type.isVoid) {
        writeln('  int64_t result = *${cast('int64_t*')}(buffer + 48);');
        if (!type.isPrimitive) {
          writeln('  char* memory = reinterpret_cast<char*>(result);');
          writeln('  jobject rootSegment = getRootSegment(env, memory);');
          writeln('  jclass resultClass = '
                  'env->FindClass("fletch/${type.identifier}");');
          writeln('  jmethodID create = env->GetStaticMethodID('
                  'resultClass, "create", '
                  '"(Ljava/lang/Object;)Lfletch/${type.identifier};");');
          writeln('  jobject resultObject = env->CallStaticObjectMethod('
                  'resultClass, create, rootSegment);');
        }
      }
      writeln('  jclass clazz = env->GetObjectClass(info->callback);');
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
      writeln('  detachCurrentThread(info->vm);');
      writeln('  delete info;');
      writeln('  free(buffer);');
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
  buffer.writeln('APP_ABI := all');
  writeToFile(join(out, 'jni'), 'Application', buffer.toString(),
      extension: 'mk');

}
