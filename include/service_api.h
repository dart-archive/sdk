// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_SERVICE_API_H_
#define INCLUDE_SERVICE_API_H_

#ifdef _MSC_VER
// TODO(herhut): Do we need a __declspec here for Windows?
#define FLETCH_VISIBILITY_DEFAULT
#else
#define FLETCH_VISIBILITY_DEFAULT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
#define FLETCH_EXPORT extern "C" FLETCH_VISIBILITY_DEFAULT
#else
#define FLETCH_EXPORT FLETCH_VISIBILITY_DEFAULT
#endif

#include <stddef.h>

typedef void* ServiceId;
typedef void* MethodId;

typedef void (*ServiceApiCallback)(void* buffer);

static const ServiceId kNoServiceId = NULL;
static const MethodId kTerminateMethodId = NULL;

// Setup must be called before using any of the other service API
// methods.
FLETCH_EXPORT void ServiceApiSetup();

// TearDown should be called when an application is done using the
// service API in order to free up resources.
FLETCH_EXPORT void ServiceApiTearDown();

FLETCH_EXPORT ServiceId ServiceApiLookup(const char* name);

FLETCH_EXPORT void ServiceApiInvoke(ServiceId service,
                                    MethodId method,
                                    void* buffer,
                                    int size);

FLETCH_EXPORT void ServiceApiInvokeAsync(ServiceId service,
                                         MethodId method,
                                         ServiceApiCallback callback,
                                         void* buffer,
                                         int size);

FLETCH_EXPORT void ServiceApiTerminate(ServiceId service);

#endif  // INCLUDE_SERVICE_API_H_
