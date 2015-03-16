// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include <jni.h>
#include <stdlib.h>
#include <string.h>

#include "service_api.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef ANDROID
  typedef JNIEnv* AttachEnvType;
#else
  typedef void* AttachEnvType;
#endif

static ServiceId service_id_ = kNoServiceId;

JNIEXPORT void JNICALL Java_fletch_ConformanceService_Setup(JNIEnv*, jclass) {
  service_id_ = ServiceApiLookup("ConformanceService");
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_TearDown(JNIEnv*, jclass) {
  ServiceApiTerminate(service_id_);
}

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
    int size = 56 + (number_of_segments * 16);
    *buffer = reinterpret_cast<char*>(malloc(size));
    int offset = 56;
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
    *reinterpret_cast<int32_t*>(*buffer + 40) = number_of_segments;
    // Set the callback information.
    *reinterpret_cast<CallbackInfo**>(*buffer + 32) = info;
    return size;
  }

  jbyteArray segment = (jbyteArray)env->GetObjectArrayElement(segments, 0);
  jint segment_length = sizes[0];
  *buffer = ExtractByteArrayData(env, segment, segment_length);
  env->ReleaseIntArrayElements(sizes_array, sizes, JNI_ABORT);
  // Mark the request as being non-segmented.
  *reinterpret_cast<int64_t*>(*buffer + 40) = 0;
  // Set the callback information.
  *reinterpret_cast<CallbackInfo**>(*buffer + 32) = info;
  return segment_length;
}

static void DeleteMessage(char* message) {
  int32_t segments = *reinterpret_cast<int32_t*>(message + 40);
  for (int i = 0; i < segments; i++) {
    int64_t address = *reinterpret_cast<int64_t*>(message + 56 + (i * 16));
    char* memory = reinterpret_cast<char*>(address);
    free(memory);
  }
  free(message);
}

static const MethodId _kgetAgeId = reinterpret_cast<MethodId>(1);

JNIEXPORT jint JNICALL Java_fletch_ConformanceService_getAge(JNIEnv* _env, jclass, jobject person) {
  char* buffer = NULL;
  int size = ComputeMessage(_env, person, NULL, NULL, &buffer);
  ServiceApiInvoke(service_id_, _kgetAgeId, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  return result;
}

static void Unwrap_int32_24(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(I)V");
  env->CallVoidMethod(info->callback, methodId, result);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_getAgeAsync(JNIEnv* _env, jclass, jobject person, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = ComputeMessage(_env, person, callback, vm, &buffer);
  ServiceApiInvokeAsync(service_id_, _kgetAgeId, Unwrap_int32_24, buffer, size);
}

static const MethodId _kgetBoxedAgeId = reinterpret_cast<MethodId>(2);

JNIEXPORT jint JNICALL Java_fletch_ConformanceService_getBoxedAge(JNIEnv* _env, jclass, jobject box) {
  char* buffer = NULL;
  int size = ComputeMessage(_env, box, NULL, NULL, &buffer);
  ServiceApiInvoke(service_id_, _kgetBoxedAgeId, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  return result;
}

static void Unwrap_int32_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(I)V");
  env->CallVoidMethod(info->callback, methodId, result);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_getBoxedAgeAsync(JNIEnv* _env, jclass, jobject box, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = ComputeMessage(_env, box, callback, vm, &buffer);
  ServiceApiInvokeAsync(service_id_, _kgetBoxedAgeId, Unwrap_int32_8, buffer, size);
}

static const MethodId _kgetAgeStatsId = reinterpret_cast<MethodId>(3);

JNIEXPORT jobject JNICALL Java_fletch_ConformanceService_getAgeStats(JNIEnv* _env, jclass, jobject person) {
  char* buffer = NULL;
  int size = ComputeMessage(_env, person, NULL, NULL, &buffer);
  ServiceApiInvoke(service_id_, _kgetAgeStatsId, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(_env, memory);
  jclass resultClass = _env->FindClass("fletch/AgeStats");
  jmethodID create = _env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/AgeStats;");
  jobject resultObject = _env->CallStaticObjectMethod(resultClass, create, rootSegment);
  return resultObject;
}

static void Unwrap_AgeStats_24(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(env, memory);
  jclass resultClass = env->FindClass("fletch/AgeStats");
  jmethodID create = env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/AgeStats;");
  jobject resultObject = env->CallStaticObjectMethod(resultClass, create, rootSegment);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(Lfletch/AgeStats;)V");
  env->CallVoidMethod(info->callback, methodId, resultObject);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_getAgeStatsAsync(JNIEnv* _env, jclass, jobject person, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = ComputeMessage(_env, person, callback, vm, &buffer);
  ServiceApiInvokeAsync(service_id_, _kgetAgeStatsId, Unwrap_AgeStats_24, buffer, size);
}

static const MethodId _kcreateAgeStatsId = reinterpret_cast<MethodId>(4);

JNIEXPORT jobject JNICALL Java_fletch_ConformanceService_createAgeStats(JNIEnv* _env, jclass, jint averageAge, jint sum) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = averageAge;
  *reinterpret_cast<jint*>(_buffer + 52) = sum;
  ServiceApiInvoke(service_id_, _kcreateAgeStatsId, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(_env, memory);
  jclass resultClass = _env->FindClass("fletch/AgeStats");
  jmethodID create = _env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/AgeStats;");
  jobject resultObject = _env->CallStaticObjectMethod(resultClass, create, rootSegment);
  return resultObject;
}

static void Unwrap_AgeStats_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(env, memory);
  jclass resultClass = env->FindClass("fletch/AgeStats");
  jmethodID create = env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/AgeStats;");
  jobject resultObject = env->CallStaticObjectMethod(resultClass, create, rootSegment);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(Lfletch/AgeStats;)V");
  env->CallVoidMethod(info->callback, methodId, resultObject);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_createAgeStatsAsync(JNIEnv* _env, jclass, jint averageAge, jint sum, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = averageAge;
  *reinterpret_cast<jint*>(_buffer + 52) = sum;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kcreateAgeStatsId, Unwrap_AgeStats_8, _buffer, kSize);
}

static const MethodId _kcreatePersonId = reinterpret_cast<MethodId>(5);

JNIEXPORT jobject JNICALL Java_fletch_ConformanceService_createPerson(JNIEnv* _env, jclass, jint children) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = children;
  ServiceApiInvoke(service_id_, _kcreatePersonId, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(_env, memory);
  jclass resultClass = _env->FindClass("fletch/Person");
  jmethodID create = _env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/Person;");
  jobject resultObject = _env->CallStaticObjectMethod(resultClass, create, rootSegment);
  return resultObject;
}

static void Unwrap_Person_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(env, memory);
  jclass resultClass = env->FindClass("fletch/Person");
  jmethodID create = env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/Person;");
  jobject resultObject = env->CallStaticObjectMethod(resultClass, create, rootSegment);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(Lfletch/Person;)V");
  env->CallVoidMethod(info->callback, methodId, resultObject);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_createPersonAsync(JNIEnv* _env, jclass, jint children, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = children;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kcreatePersonId, Unwrap_Person_8, _buffer, kSize);
}

static const MethodId _kcreateNodeId = reinterpret_cast<MethodId>(6);

JNIEXPORT jobject JNICALL Java_fletch_ConformanceService_createNode(JNIEnv* _env, jclass, jint depth) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = depth;
  ServiceApiInvoke(service_id_, _kcreateNodeId, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(_env, memory);
  jclass resultClass = _env->FindClass("fletch/Node");
  jmethodID create = _env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/Node;");
  jobject resultObject = _env->CallStaticObjectMethod(resultClass, create, rootSegment);
  return resultObject;
}

static void Unwrap_Node_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(env, memory);
  jclass resultClass = env->FindClass("fletch/Node");
  jmethodID create = env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/Node;");
  jobject resultObject = env->CallStaticObjectMethod(resultClass, create, rootSegment);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(Lfletch/Node;)V");
  env->CallVoidMethod(info->callback, methodId, resultObject);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_createNodeAsync(JNIEnv* _env, jclass, jint depth, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = depth;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kcreateNodeId, Unwrap_Node_8, _buffer, kSize);
}

static const MethodId _kcountId = reinterpret_cast<MethodId>(7);

JNIEXPORT jint JNICALL Java_fletch_ConformanceService_count(JNIEnv* _env, jclass, jobject person) {
  char* buffer = NULL;
  int size = ComputeMessage(_env, person, NULL, NULL, &buffer);
  ServiceApiInvoke(service_id_, _kcountId, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  return result;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_countAsync(JNIEnv* _env, jclass, jobject person, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = ComputeMessage(_env, person, callback, vm, &buffer);
  ServiceApiInvokeAsync(service_id_, _kcountId, Unwrap_int32_24, buffer, size);
}

static const MethodId _kdepthId = reinterpret_cast<MethodId>(8);

JNIEXPORT jint JNICALL Java_fletch_ConformanceService_depth(JNIEnv* _env, jclass, jobject node) {
  char* buffer = NULL;
  int size = ComputeMessage(_env, node, NULL, NULL, &buffer);
  ServiceApiInvoke(service_id_, _kdepthId, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  return result;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_depthAsync(JNIEnv* _env, jclass, jobject node, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = ComputeMessage(_env, node, callback, vm, &buffer);
  ServiceApiInvokeAsync(service_id_, _kdepthId, Unwrap_int32_24, buffer, size);
}

static const MethodId _kfooId = reinterpret_cast<MethodId>(9);

JNIEXPORT void JNICALL Java_fletch_ConformanceService_foo(JNIEnv* _env, jclass) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, _kfooId, _buffer, kSize);
}

static void Unwrap_void_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  DeleteMessage(buffer);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "()V");
  env->CallVoidMethod(info->callback, methodId);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_fooAsync(JNIEnv* _env, jclass, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kfooId, Unwrap_void_8, _buffer, kSize);
}

static const MethodId _kbarId = reinterpret_cast<MethodId>(10);

JNIEXPORT jint JNICALL Java_fletch_ConformanceService_bar(JNIEnv* _env, jclass, jobject empty) {
  char* buffer = NULL;
  int size = ComputeMessage(_env, empty, NULL, NULL, &buffer);
  ServiceApiInvoke(service_id_, _kbarId, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  return result;
}

static void Unwrap_int32_0(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(I)V");
  env->CallVoidMethod(info->callback, methodId, result);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_barAsync(JNIEnv* _env, jclass, jobject empty, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = ComputeMessage(_env, empty, callback, vm, &buffer);
  ServiceApiInvokeAsync(service_id_, _kbarId, Unwrap_int32_0, buffer, size);
}

static const MethodId _kpingId = reinterpret_cast<MethodId>(11);

JNIEXPORT jint JNICALL Java_fletch_ConformanceService_ping(JNIEnv* _env, jclass) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, _kpingId, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 48);
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_pingAsync(JNIEnv* _env, jclass, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kpingId, Unwrap_int32_8, _buffer, kSize);
}

static const MethodId _kflipTableId = reinterpret_cast<MethodId>(12);

JNIEXPORT jobject JNICALL Java_fletch_ConformanceService_flipTable(JNIEnv* _env, jclass, jobject flip) {
  char* buffer = NULL;
  int size = ComputeMessage(_env, flip, NULL, NULL, &buffer);
  ServiceApiInvoke(service_id_, _kflipTableId, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(_env, memory);
  jclass resultClass = _env->FindClass("fletch/TableFlip");
  jmethodID create = _env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/TableFlip;");
  jobject resultObject = _env->CallStaticObjectMethod(resultClass, create, rootSegment);
  return resultObject;
}

static void Unwrap_TableFlip_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(env, memory);
  jclass resultClass = env->FindClass("fletch/TableFlip");
  jmethodID create = env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/TableFlip;");
  jobject resultObject = env->CallStaticObjectMethod(resultClass, create, rootSegment);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(Lfletch/TableFlip;)V");
  env->CallVoidMethod(info->callback, methodId, resultObject);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_ConformanceService_flipTableAsync(JNIEnv* _env, jclass, jobject flip, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = ComputeMessage(_env, flip, callback, vm, &buffer);
  ServiceApiInvokeAsync(service_id_, _kflipTableId, Unwrap_TableFlip_8, buffer, size);
}

#ifdef __cplusplus
}
#endif
