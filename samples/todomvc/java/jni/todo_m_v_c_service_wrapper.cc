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

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_Setup(JNIEnv*, jclass) {
  service_id_ = ServiceApiLookup("TodoMVCService");
}

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_TearDown(JNIEnv*, jclass) {
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

static const MethodId _kcreateItemId = reinterpret_cast<MethodId>(1);

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_createItem(JNIEnv* _env, jclass, jobject title) {
  char* buffer = NULL;
  int size = ComputeMessage(_env, title, NULL, NULL, &buffer);
  ServiceApiInvoke(service_id_, _kcreateItemId, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
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

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_createItemAsync(JNIEnv* _env, jclass, jobject title, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  char* buffer = NULL;
  int size = ComputeMessage(_env, title, callback, vm, &buffer);
  ServiceApiInvokeAsync(service_id_, _kcreateItemId, Unwrap_void_8, buffer, size);
}

static const MethodId _kdeleteItemId = reinterpret_cast<MethodId>(2);

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_deleteItem(JNIEnv* _env, jclass, jint id) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = id;
  ServiceApiInvoke(service_id_, _kdeleteItemId, _buffer, kSize);
}

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_deleteItemAsync(JNIEnv* _env, jclass, jint id, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = id;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kdeleteItemId, Unwrap_void_8, _buffer, kSize);
}

static const MethodId _kcompleteItemId = reinterpret_cast<MethodId>(3);

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_completeItem(JNIEnv* _env, jclass, jint id) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = id;
  ServiceApiInvoke(service_id_, _kcompleteItemId, _buffer, kSize);
}

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_completeItemAsync(JNIEnv* _env, jclass, jint id, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = id;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kcompleteItemId, Unwrap_void_8, _buffer, kSize);
}

static const MethodId _kuncompleteItemId = reinterpret_cast<MethodId>(4);

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_uncompleteItem(JNIEnv* _env, jclass, jint id) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = id;
  ServiceApiInvoke(service_id_, _kuncompleteItemId, _buffer, kSize);
}

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_uncompleteItemAsync(JNIEnv* _env, jclass, jint id, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jint*>(_buffer + 48) = id;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kuncompleteItemId, Unwrap_void_8, _buffer, kSize);
}

static const MethodId _kclearItemsId = reinterpret_cast<MethodId>(5);

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_clearItems(JNIEnv* _env, jclass) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, _kclearItemsId, _buffer, kSize);
}

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_clearItemsAsync(JNIEnv* _env, jclass, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kclearItemsId, Unwrap_void_8, _buffer, kSize);
}

static const MethodId _kdispatchId = reinterpret_cast<MethodId>(6);

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_dispatch(JNIEnv* _env, jclass, jchar id) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jchar*>(_buffer + 48) = id;
  ServiceApiInvoke(service_id_, _kdispatchId, _buffer, kSize);
}

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_dispatchAsync(JNIEnv* _env, jclass, jchar id, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  *reinterpret_cast<jchar*>(_buffer + 48) = id;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kdispatchId, Unwrap_void_8, _buffer, kSize);
}

static const MethodId _ksyncId = reinterpret_cast<MethodId>(7);

JNIEXPORT jobject JNICALL Java_fletch_TodoMVCService_sync(JNIEnv* _env, jclass) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, _ksyncId, _buffer, kSize);
  int64_t result = *reinterpret_cast<int64_t*>(_buffer + 48);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(_env, memory);
  jclass resultClass = _env->FindClass("fletch/PatchSet");
  jmethodID create = _env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/PatchSet;");
  jobject resultObject = _env->CallStaticObjectMethod(resultClass, create, rootSegment);
  return resultObject;
}

static void Unwrap_PatchSet_8(void* raw) {
  char* buffer = reinterpret_cast<char*>(raw);
  CallbackInfo* info = *reinterpret_cast<CallbackInfo**>(buffer + 32);
  JNIEnv* env = AttachCurrentThreadAndGetEnv(info->vm);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 48);
  DeleteMessage(buffer);
  char* memory = reinterpret_cast<char*>(result);
  jobject rootSegment = GetRootSegment(env, memory);
  jclass resultClass = env->FindClass("fletch/PatchSet");
  jmethodID create = env->GetStaticMethodID(resultClass, "create", "(Ljava/lang/Object;)Lfletch/PatchSet;");
  jobject resultObject = env->CallStaticObjectMethod(resultClass, create, rootSegment);
  jclass clazz = env->GetObjectClass(info->callback);
  jmethodID methodId = env->GetMethodID(clazz, "handle", "(Lfletch/PatchSet;)V");
  env->CallVoidMethod(info->callback, methodId, resultObject);
  env->DeleteGlobalRef(info->callback);
  DetachCurrentThread(info->vm);
  delete info;
}

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_syncAsync(JNIEnv* _env, jclass, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _ksyncId, Unwrap_PatchSet_8, _buffer, kSize);
}

static const MethodId _kresetId = reinterpret_cast<MethodId>(8);

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_reset(JNIEnv* _env, jclass) {
  static const int kSize = 56;
  char _bits[kSize];
  char* _buffer = _bits;
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  ServiceApiInvoke(service_id_, _kresetId, _buffer, kSize);
}

JNIEXPORT void JNICALL Java_fletch_TodoMVCService_resetAsync(JNIEnv* _env, jclass, jobject _callback) {
  jobject callback = _env->NewGlobalRef(_callback);
  JavaVM* vm;
  _env->GetJavaVM(&vm);
  static const int kSize = 56 + 1 * sizeof(void*);
  char* _buffer = reinterpret_cast<char*>(malloc(kSize));
  *reinterpret_cast<int64_t*>(_buffer + 40) = 0;
  CallbackInfo* info = new CallbackInfo(callback, vm);
  *reinterpret_cast<CallbackInfo**>(_buffer + 32) = info;
  ServiceApiInvokeAsync(service_id_, _kresetId, Unwrap_void_8, _buffer, kSize);
}

#ifdef __cplusplus
}
#endif
