// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include <jni.h>
#include <stdlib.h>

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

JNIEXPORT void JNICALL Java_fletch_PerformanceService_Setup(JNIEnv*, jclass) {
  service_id_ = ServiceApiLookup("PerformanceService");
}

JNIEXPORT void JNICALL Java_fletch_PerformanceService_TearDown(JNIEnv*, jclass) {
  ServiceApiTerminate(service_id_);
}

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
}

static const MethodId _kechoId = reinterpret_cast<MethodId>(1);

JNIEXPORT jint JNICALL Java_fletch_PerformanceService_echo(JNIEnv* _env, jclass, jint n) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = n;
  ServiceApiInvoke(service_id_, _kechoId, _buffer, kSize);
  return *reinterpret_cast<int64_t*>(_buffer + 48);
}

static void Unwrap_int32_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = attachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(I)V");
  env->CallVoidMethod(info->callback, methodId, result);
  env->DeleteGlobalRef(info->callback);
  detachCurrentThread(info->vm);
  delete info;
  free(buffer);
}

JNIEXPORT void JNICALL Java_fletch_PerformanceService_echoAsync(JNIEnv* _env, jclass, jint n, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = n;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kechoId, Unwrap_int32_8, _buffer, kSize);
}

static const MethodId _kcountTreeNodesId = reinterpret_cast<MethodId>(2);

JNIEXPORT jint JNICALL Java_fletch_PerformanceService_countTreeNodes(JNIEnv* _env, jclass, jobject node) {
  char* buffer = NULL;
  int size = computeMessage(_env, node, &buffer, NULL, NULL);
  ServiceApiInvoke(service_id_, _kcountTreeNodesId, buffer, size);
  return *reinterpret_cast<int64_t*>(buffer + 48);
}

JNIEXPORT void JNICALL Java_fletch_PerformanceService_countTreeNodesAsync(JNIEnv* _env, jclass, jobject node, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = computeMessage(_env, node, &buffer, callback, vm);
  ServiceApiInvokeAsync(service_id_, _kcountTreeNodesId, Unwrap_int32_8, buffer, size);
}

static const MethodId _kbuildTreeId = reinterpret_cast<MethodId>(3);

JNIEXPORT jobject JNICALL Java_fletch_PerformanceService_buildTree(JNIEnv* _env, jclass, jint n) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = n;
  ServiceApiInvoke(service_id_, _kbuildTreeId, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = getRootSegment(_env, memory);
  jclass resultClass = _env->FindClass("fletch/TreeNode");
  jmethodID create = _env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/TreeNode;");
  jobject resultObject = _env->CallStaticObjectMethod(resultClass, create, rootSegment);
  return resultObject;
}

static void Unwrap_TreeNode_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = attachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = getRootSegment(env, memory);
  jclass resultClass = env->FindClass("fletch/TreeNode");
  jmethodID create = env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/TreeNode;");
  jobject resultObject = env->CallStaticObjectMethod(resultClass, create, rootSegment);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(Lfletch/TreeNode;)V");
  env->CallVoidMethod(info->callback, methodId, resultObject);
  env->DeleteGlobalRef(info->callback);
  detachCurrentThread(info->vm);
  delete info;
  free(buffer);
}

JNIEXPORT void JNICALL Java_fletch_PerformanceService_buildTreeAsync(JNIEnv* _env, jclass, jint n, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = n;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kbuildTreeId, Unwrap_TreeNode_8, _buffer, kSize);
}

#ifdef __cplusplus
}
#endif
