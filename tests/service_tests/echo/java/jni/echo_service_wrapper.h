// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <jni.h>

#ifndef _fletch_EchoService
#define _fletch_EchoService

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT void JNICALL Java_fletch_EchoService_Setup(JNIEnv*, jclass);
JNIEXPORT void JNICALL Java_fletch_EchoService_TearDown(JNIEnv*, jclass);
JNIEXPORT jint JNICALL Java_fletch_EchoService_Echo(JNIEnv*, jclass, jint);

#ifdef __cplusplus
}
#endif

#endif
