// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include <jni.h>

#include "service_api.h"

#ifdef __cplusplus
extern "C" {
#endif

static ServiceId _service_id = kNoServiceId;

JNIEXPORT void JNICALL Java_fletch_EchoService_Setup(JNIEnv*, jclass) {
  _service_id = ServiceApiLookup("EchoService");
}

JNIEXPORT void JNICALL Java_fletch_EchoService_TearDown(JNIEnv*, jclass) {
  ServiceApiTerminate(_service_id);
}

static const MethodId _kEchoId = reinterpret_cast<MethodId>(1);

JNIEXPORT jint JNICALL Java_fletch_EchoService_Echo(JNIEnv*, jclass, jint n) {
  char _bits[36];
  char* _buffer = _bits;
  *reinterpret_cast<int*>(_buffer + 32) = n;
  ServiceApiInvokeX(_service_id, _kEchoId, _buffer, 36);
  return *reinterpret_cast<int*>(_buffer + 32);
}

static const MethodId _kSumId = reinterpret_cast<MethodId>(2);

JNIEXPORT jint JNICALL Java_fletch_EchoService_Sum(JNIEnv*, jclass, jint x, jint y) {
  char _bits[40];
  char* _buffer = _bits;
  *reinterpret_cast<int*>(_buffer + 32) = x;
  *reinterpret_cast<int*>(_buffer + 36) = y;
  ServiceApiInvokeX(_service_id, _kSumId, _buffer, 40);
  return *reinterpret_cast<int*>(_buffer + 32);
}

#ifdef __cplusplus
}
#endif
