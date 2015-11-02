// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_MACOS)

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include <pthread.h>

#include "include/dart_api.h"
#include "include/dart_native_api.h"


#include "/usr/include/dns_sd.h"

#include "mdns_extension.h"

// Context passed to the callback receiving the mDNS information.
struct Context {
  // The Dart port where the result should be delivered.
  Dart_Port port;
};

// Print fatal error and exit.
static void Fatal(const char *message) {
  fprintf(stderr, "%s (errno %d)\n", message, errno);
  exit(-1);
}

// Code running in the threads started for pumping the results.
static void* ThreadFunction(void* data) {
  DNSServiceRef ref = reinterpret_cast<DNSServiceRef>(data);

  // Preocess results until an error occurs.
  DNSServiceErrorType result = kDNSServiceErr_NoError;
  while (result == kDNSServiceErr_NoError) {
    result = DNSServiceProcessResult(ref);
  }
  // The expected error from deallocation the ref.
  if (result != kDNSServiceErr_BadReference) {
    fprintf(stderr, "Error from DNSServiceProcessResult: %d\n", result);
  }

  return NULL;
}

// Start a thread for receiving results from a specific DNSServiceRef.
static int StartThread(DNSServiceRef ref) {
  pthread_attr_t attr;
  int result = pthread_attr_init(&attr);
  if (result != 0) Fatal("Error from pthread_attr_init");

  result = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
  if (result != 0) Fatal("Error from pthread_attr_setdetachstate");

  pthread_t tid;
  result = pthread_create(&tid, &attr, ThreadFunction, ref);
  if (result != 0) Fatal("Error from pthread_create");

  result = pthread_attr_destroy(&attr);
  if (result != 0) Fatal("Error from pthread_attr_destroy");

  return 0;
}

// Callback for results initiated by calling DNSServiceGetAddrInfo.
static void GetAddrInfoCallback(DNSServiceRef ref,
                                DNSServiceFlags flags,
                                uint32_t interfaceIndex,
                                DNSServiceErrorType errorCode,
                                const char *hostname,
                                const struct sockaddr *address,
                                uint32_t ttl,
                                void *context) {
  if (address->sa_family == AF_INET) {
    const struct sockaddr_in* address_in = (const struct sockaddr_in*)address;
    const uint8_t* addr =
        reinterpret_cast<const uint8_t*>(&address_in->sin_addr.s_addr);

    struct Context* ctx = reinterpret_cast<struct Context*>(context);

    // Build the response message.
    Dart_CObject cobject_hostname;
    cobject_hostname.type = Dart_CObject_kString;
    cobject_hostname.value.as_string = const_cast<char*>(hostname);
    Dart_CObject cobject_address;
    cobject_address.type = Dart_CObject_kTypedData;
    cobject_address.value.as_typed_data.length = 4;
    cobject_address.value.as_typed_data.type = Dart_TypedData_kUint8;
    cobject_address.value.as_typed_data.values = const_cast<uint8_t*>(addr);
    Dart_CObject cobject_result;
    cobject_result.type = Dart_CObject_kArray;
    Dart_CObject* result_array[] = {&cobject_hostname, &cobject_address};
    cobject_result.value.as_array.length = 2;
    cobject_result.value.as_array.values = result_array;
    Dart_PostCObject(ctx->port, &cobject_result);

    // Result received, free allocated data and stop lookup.
    free(ctx);
    DNSServiceRefDeallocate(ref);
  }
}

// Lookup request from Dart.
void HandleLookup(Dart_Port port_id, char* hostname) {
  DNSServiceRef ref;
  DNSServiceErrorType result;
  struct Context* context =
      reinterpret_cast<struct Context*>(malloc(sizeof(struct Context)));
  context->port = port_id;
  result = DNSServiceGetAddrInfo(&ref,
                                 0,
                                 0,
                                 kDNSServiceProtocol_IPv4,
                                 hostname,
                                 &GetAddrInfoCallback,
                                 context);
  if (result != kDNSServiceErr_NoError) {
    fprintf(stderr, "Error from DNSServiceProcessResult: %d\n", result);
  } else {
    // Start a thread for retreiving the results.
    // TODO(sgjesse): Add a timeout for killing the thread if there
    // are no responses.
    StartThread(ref);
  }
}

#endif
