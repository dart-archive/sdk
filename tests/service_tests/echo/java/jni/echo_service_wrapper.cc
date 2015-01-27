// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <jni.h>

#include "service_api.h"

static const MethodId kEchoMethodId = reinterpret_cast<MethodId>(1);
static ServiceId service_id = kNoServiceId;

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT void JNICALL Java_fletch_EchoService_Setup(JNIEnv*, jclass) {
  service_id = ServiceApiLookup("EchoService");
}

JNIEXPORT void JNICALL Java_fletch_EchoService_TearDown(JNIEnv*, jclass) {
  ServiceApiTerminate(service_id);
}

JNIEXPORT jint JNICALL Java_fletch_EchoService_Echo(JNIEnv*, jclass, jint arg) {
  return ServiceApiInvoke(service_id, kEchoMethodId, arg);
}

#ifdef __cplusplus
}
#endif
