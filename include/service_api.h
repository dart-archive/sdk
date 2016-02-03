// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_SERVICE_API_H_
#define INCLUDE_SERVICE_API_H_

#ifdef _MSC_VER
// TODO(herhut): Do we need a __declspec here for Windows?
#define DARTINO_VISIBILITY_DEFAULT
#else
#define DARTINO_VISIBILITY_DEFAULT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
#define DARTINO_EXPORT extern "C" DARTINO_VISIBILITY_DEFAULT
#else
#define DARTINO_EXPORT DARTINO_VISIBILITY_DEFAULT
#endif

#include <stddef.h>

typedef void* ServiceId;
typedef void* MethodId;

typedef void (*ServiceApiCallback)(void* buffer);

static const ServiceId kNoServiceId = NULL;
static const MethodId kTerminateMethodId = NULL;

// Setup must be called before using any of the other service API
// methods.
DARTINO_EXPORT void ServiceApiSetup();

// TearDown should be called when an application is done using the
// service API in order to free up resources.
DARTINO_EXPORT void ServiceApiTearDown();

DARTINO_EXPORT ServiceId ServiceApiLookup(const char* name);

DARTINO_EXPORT void ServiceApiInvoke(ServiceId service,
                                    MethodId method,
                                    void* buffer,
                                    int size);

DARTINO_EXPORT void ServiceApiInvokeAsync(ServiceId service,
                                         MethodId method,
                                         ServiceApiCallback callback,
                                         void* buffer,
                                         int size);

DARTINO_EXPORT void ServiceApiTerminate(ServiceId service);

#endif  // INCLUDE_SERVICE_API_H_
