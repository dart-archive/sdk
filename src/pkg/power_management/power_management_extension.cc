// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "power_management_extension.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "include/dart_api.h"
#include "include/dart_native_api.h"

// Handler for the echo request. Used for testing that the native extension
// can be loaded and called.
void HandleEcho(Dart_Port reply_port, Dart_CObject* argument) {
  Dart_PostCObject(reply_port, argument);
}

Dart_Handle HandleError(Dart_Handle handle) {
  if (Dart_IsError(handle)) Dart_PropagateError(handle);
  return handle;
}

void DisableSleep(Dart_NativeArguments arguments) {
  Dart_Handle reason_object =
      HandleError(Dart_GetNativeArgument(arguments, 0));
  if (Dart_IsString(reason_object)) {
    const char* reason;
    HandleError(Dart_StringToCString(reason_object, &reason));
    int64_t id = HandleDisableSleep(reason);
    Dart_SetReturnValue(arguments, HandleError(Dart_NewInteger(id)));
  } else {
    Dart_SetReturnValue(arguments, HandleError(Dart_NewInteger(-1)));
  }
}

void EnableSleep(Dart_NativeArguments arguments) {
  Dart_SetReturnValue(arguments, Dart_Null());
  Dart_Handle id_object =
      HandleError(Dart_GetNativeArgument(arguments, 0));
  if (Dart_IsInteger(id_object)) {
    bool fits;
    HandleError(Dart_IntegerFitsIntoInt64(id_object, &fits));
    if (fits) {
      int64_t id;
      HandleError(Dart_IntegerToInt64(id_object, &id));
      HandleEnableSleep(id);
    }
  }
}

// Resolver for the extension library.
Dart_NativeFunction ResolveName(Dart_Handle name, int argc,
                                bool* auto_setup_scope) {
  const char* c_name;
  Dart_Handle check_error;

  check_error = Dart_StringToCString(name, &c_name);
  if (Dart_IsError(check_error)) {
    Dart_PropagateError(check_error);
  }
  if ((strcmp("PowerManagementExtension_DisableSleep", c_name) == 0) &&
      (argc == 1)) {
    return DisableSleep;
  }
  if ((strcmp("PowerManagementExtension_EnableSleep", c_name) == 0) &&
      (argc == 1)) {
    return EnableSleep;
  }
  return NULL;
}

// Entry point for the extension library.
DART_EXPORT Dart_Handle power_management_extension_lib_Init(
    Dart_Handle parent_library) {
  Dart_Handle result_code;
  if (Dart_IsError(parent_library)) {
    return parent_library;
  }

  result_code = Dart_SetNativeResolver(parent_library, ResolveName, NULL);
  if (Dart_IsError(result_code)) {
    return result_code;
  }

  return parent_library;
}
