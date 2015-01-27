// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <jni.h>

#ifndef _fletch_FletchApi
#define _fletch_FletchApi

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT void JNICALL Java_fletch_FletchApi_Setup(JNIEnv*, jclass);
JNIEXPORT void JNICALL Java_fletch_FletchApi_TearDown(JNIEnv*, jclass);
JNIEXPORT void JNICALL Java_fletch_FletchApi_RunSnapshot(JNIEnv*,
                                                         jclass,
                                                         jbyteArray);
JNIEXPORT void JNICALL Java_fletch_FletchApi_AddDefaultSharedLibrary(JNIEnv*,
                                                                     jclass,
                                                                     jstring);

#ifdef __cplusplus
}
#endif

#endif
