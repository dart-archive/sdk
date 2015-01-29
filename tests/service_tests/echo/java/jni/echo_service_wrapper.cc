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

static ServiceId _service_id = kNoServiceId;

JNIEXPORT void JNICALL Java_fletch_EchoService_Setup(JNIEnv*, jclass) {
  _service_id = ServiceApiLookup("EchoService");
}

JNIEXPORT void JNICALL Java_fletch_EchoService_TearDown(JNIEnv*, jclass) {
  ServiceApiTerminate(_service_id);
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

static const MethodId _kEchoId = reinterpret_cast<MethodId>(1);

JNIEXPORT jint JNICALL Java_fletch_EchoService_Echo(JNIEnv*, jclass, jint n) {
  static const int kSize = 36;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int*>(_buffer + 32) = n;
  ServiceApiInvoke(_service_id, _kEchoId, _buffer, kSize);
  return *reinterpret_cast<int*>(_buffer + 32);
}

static void Unwrap_Int32_1(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  int result = *reinterpret_cast<int*>(buffer + 32);
  jobject callback = *reinterpret_cast<jobject*>(buffer + 36);
  JavaVM* vm = *reinterpret_cast<JavaVM**>(buffer + 36 + sizeof(void*));
  JNIEnv* env = attachCurrentThreadAndGetEnv(vm);
  jclass clazz = env->GetObjectClass(callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(I)V");
  env->CallVoidMethod(callback, methodId, result);
  env->DeleteGlobalRef(callback);
  detachCurrentThread(vm);
  free(buffer);
}

JNIEXPORT void JNICALL Java_fletch_EchoService_EchoAsync(JNIEnv* _env, jclass, jint n, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 36 + 2 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int*>(_buffer + 32) = n;
  *reinterpret_cast<void**>(_buffer + 36) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 36 + 1 * sizeof(void*)) = reinterpret_cast<void*>(vm);
  ServiceApiInvokeAsync(_service_id, _kEchoId, Unwrap_Int32_1, _buffer, kSize);
}

static const MethodId _kSumId = reinterpret_cast<MethodId>(2);

JNIEXPORT jint JNICALL Java_fletch_EchoService_Sum(JNIEnv*, jclass, jint x, jint y) {
  static const int kSize = 40;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int*>(_buffer + 32) = x;
  *reinterpret_cast<int*>(_buffer + 36) = y;
  ServiceApiInvoke(_service_id, _kSumId, _buffer, kSize);
  return *reinterpret_cast<int*>(_buffer + 32);
}

static void Unwrap_Int32_2(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  int result = *reinterpret_cast<int*>(buffer + 32);
  jobject callback = *reinterpret_cast<jobject*>(buffer + 40);
  JavaVM* vm = *reinterpret_cast<JavaVM**>(buffer + 40 + sizeof(void*));
  JNIEnv* env = attachCurrentThreadAndGetEnv(vm);
  jclass clazz = env->GetObjectClass(callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(I)V");
  env->CallVoidMethod(callback, methodId, result);
  env->DeleteGlobalRef(callback);
  detachCurrentThread(vm);
  free(buffer);
}

JNIEXPORT void JNICALL Java_fletch_EchoService_SumAsync(JNIEnv* _env, jclass, jint x, jint y, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 40 + 2 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int*>(_buffer + 32) = x;
  *reinterpret_cast<int*>(_buffer + 36) = y;
  *reinterpret_cast<void**>(_buffer + 40) = reinterpret_cast<void*>(callback);
  *reinterpret_cast<void**>(_buffer + 40 + 1 * sizeof(void*)) = reinterpret_cast<void*>(vm);
  ServiceApiInvokeAsync(_service_id, _kSumId, Unwrap_Int32_2, _buffer, kSize);
}

#ifdef __cplusplus
}
#endif
