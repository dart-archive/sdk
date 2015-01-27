// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "fletch_api_wrapper.h"

#include "fletch_api.h"

void Java_fletch_FletchApi_Setup(JNIEnv*, jclass) {
  FletchSetup();
}

void Java_fletch_FletchApi_TearDown(JNIEnv*, jclass) {
  FletchTearDown();
}

void Java_fletch_FletchApi_RunSnapshot(JNIEnv* env,
                                       jclass,
                                       jbyteArray snapshot) {
  // TODO(ager): Avoid copying the snapshot. You can easily get a file
  // path from an Android resource so we copy for now. The long term
  // solution should probably be to compile the snapshot into the
  // fletch library and run the snapshot that has been compiled into
  // the library with no copying.
  int len = env->GetArrayLength(snapshot);
  unsigned char* copy = new unsigned char[len];
  env->GetByteArrayRegion(snapshot, 0, len, reinterpret_cast<jbyte*>(copy));
  FletchRunSnapshot(copy, len);
  delete copy;
}

void Java_fletch_FletchApi_AddDefaultSharedLibrary(JNIEnv* env,
                                                   jclass,
                                                   jstring str) {
  const char* library = env->GetStringUTFChars(str, 0);
  FletchAddDefaultSharedLibrary(library);
  env->ReleaseStringUTFChars(str, library);
}
