// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "mdns_extension.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "include/dart_api.h"
#include "include/dart_native_api.h"

// Handle request send on the service port.
void HandleRequest(Dart_Port port_id, Dart_CObject* message) {
  // Messages are expected to be three item lists:
  //  [0]: reply port
  //  [1]: request type
  //  [2]: request argument
  if (message->type == Dart_CObject_kArray &&
      message->value.as_array.length > 2) {
    Dart_CObject* reply_port = message->value.as_array.values[0];
    Dart_CObject* request_type = message->value.as_array.values[1];
    if (reply_port->type == Dart_CObject_kSendPort &&
        request_type->type == Dart_CObject_kInt32) {
      switch (request_type->value.as_int32) {
        case kEchoRequest:
          if (message->value.as_array.length == 3) {
            Dart_CObject* argument = message->value.as_array.values[2];
            HandleEcho(reply_port->value.as_send_port.id, argument);
            return;
          }

        case kLookupRequest:
          if (message->value.as_array.length == 5) {
            Dart_CObject* type = message->value.as_array.values[2];
            Dart_CObject* name = message->value.as_array.values[3];
            Dart_CObject* timeout = message->value.as_array.values[4];
            if (type->type == Dart_CObject_kInt32 &&
                name->type == Dart_CObject_kString &&
                timeout->type == Dart_CObject_kInt32) {
              HandleLookup(reply_port->value.as_send_port.id,
                           type->value.as_int32, name->value.as_string,
                           timeout->value.as_int32);
            }
            return;
          }

        default:
          break;
          // Ignore invalid requests.
      }
    }
    Dart_CObject result;
    result.type = Dart_CObject_kNull;
    Dart_PostCObject(reply_port->value.as_send_port.id, &result);
  }
}

// Handler for the echo request. Used for testing that the native extension
// can be loaded and called.
void HandleEcho(Dart_Port reply_port, Dart_CObject* argument) {
  Dart_PostCObject(reply_port, argument);
}

Dart_Handle HandleError(Dart_Handle handle) {
  if (Dart_IsError(handle)) Dart_PropagateError(handle);
  return handle;
}

// Initialize a native port with a request handler.
void ServicePort(Dart_NativeArguments arguments) {
  Dart_SetReturnValue(arguments, Dart_Null());
  Dart_Port service_port =
      Dart_NewNativePort("MDnsService", HandleRequest, true);
  if (service_port != ILLEGAL_PORT) {
    Dart_Handle send_port = Dart_NewSendPort(service_port);
    Dart_SetReturnValue(arguments, send_port);
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
  if ((strcmp("MDnsExtension_ServicePort", c_name) == 0) && (argc == 0)) {
    return ServicePort;
  }
  return NULL;
}

// Entry point for the extension library.
DART_EXPORT Dart_Handle mdns_extension_lib_Init(Dart_Handle parent_library) {
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
