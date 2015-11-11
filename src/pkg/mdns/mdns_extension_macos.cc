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
#include <sys/time.h>

#include <dns_sd.h>

#include "include/dart_api.h"
#include "include/dart_native_api.h"

#include "mdns_extension.h"

// Constants.
static uint32_t kUsecsInSecs = 1000000;
static uint32_t kMillisecsInUsecs = 1000;

// Context passed to the callback receiving the mDNS information.
struct Context {
  DNSServiceRef ref;
  // The timeout waiting for results.
  int timeout;
  // The Dart port where the result should be delivered.
  Dart_Port port;
};

// Print fatal error and exit.
static void Fatal(const char *message) {
  fprintf(stderr, "%s (errno %d)\n", message, errno);
  exit(-1);
}

int64_t timeval_to_usec(const struct timeval* tv) {
  return( (int64_t)tv->tv_sec * kUsecsInSecs + tv->tv_usec ) ;
}

struct timeval* usec_to_timeval(int64_t usec, struct timeval* tv) {
  tv->tv_sec = usec / kUsecsInSecs;
  tv->tv_usec = usec % kUsecsInSecs;
  return tv;
}

// Free allocated resources associated with a context.
static void FreeContext(Context* ctx) {
  DNSServiceRefDeallocate(ctx->ref);
  free(ctx);
}

// Code running in the threads started for pumping the results.
static void* ThreadFunction(void* data) {
  Context* ctx = reinterpret_cast<Context*>(data);

  // Determint the end-time for responses to this request. Timeout from Dart
  // is in milliseconds.
  struct timeval time;
  if (gettimeofday(&time, NULL) == -1) {
    FreeContext(ctx);
    return NULL;
  }
  int64_t end_time = timeval_to_usec(&time) + ctx->timeout * kMillisecsInUsecs;

  // Setup single file descriptor for select.
  int fd = DNSServiceRefSockFD(ctx->ref);
  fd_set readfds;
  FD_ZERO(&readfds);
  FD_SET(fd, &readfds);
  while (true) {
    struct timeval timeout;
    int64_t timeout_usec = end_time - timeval_to_usec(&time);
    if (timeout_usec <= 0) break;
    usec_to_timeval(timeout_usec, &timeout);
    int rc = select(fd + 1, &readfds, NULL, NULL, &timeout);
    if (rc == -1 && errno  == EINTR) continue;

    // Terminate the loop if timeout or error.
    if (rc <= 0) break;

    // Process the result which is ready.
    DNSServiceErrorType result = DNSServiceProcessResult(ctx->ref);
    if (result != kDNSServiceErr_NoError) break;

    // Prepare new timeout.
    if (gettimeofday(&time, NULL) == -1) break;
  }

  FreeContext(ctx);
  return NULL;
}

// Start a thread for receiving results from a specific DNSServiceRef.
static int StartThread(Context* ctx) {
  pthread_attr_t attr;
  int result = pthread_attr_init(&attr);
  if (result != 0) Fatal("Error from pthread_attr_init");

  result = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
  if (result != 0) Fatal("Error from pthread_attr_setdetachstate");

  pthread_t tid;
  result = pthread_create(&tid, &attr, ThreadFunction, ctx);
  if (result != 0) Fatal("Error from pthread_create");

  result = pthread_attr_destroy(&attr);
  if (result != 0) Fatal("Error from pthread_attr_destroy");

  return 0;
}


// Callback for results initiated by calling DNSServiceQueryRecord.
static void QueryRecordCallback(DNSServiceRef ref,
                                DNSServiceFlags flags,
                                uint32_t interfaceIndex,
                                DNSServiceErrorType errorCode,
                                const char *fullname,
                                uint16_t rrtype,
                                uint16_t rrclass,
                                uint16_t rdlen,
                                const void* rdata,
                                uint32_t ttl,
                                void *context) {
  if (rrclass != kDNSServiceClass_IN) return;

  struct Context* ctx = reinterpret_cast<struct Context*>(context);

  if (rrtype != kDNSServiceType_A &&
      rrtype != kDNSServiceType_SRV &&
      rrtype != kDNSServiceType_PTR) {
    // Ignore unsupported types.
    return;
  }

  // Build the response message.
  Dart_CObject cobject_fullname;
  cobject_fullname.type = Dart_CObject_kString;
  cobject_fullname.value.as_string = const_cast<char*>(fullname);
  Dart_CObject cobject_type;
  cobject_type.type = Dart_CObject_kInt32;
  cobject_type.value.as_int32 = rrtype;
  Dart_CObject cobject_ttl;
  cobject_ttl.type = Dart_CObject_kInt32;
  cobject_ttl.value.as_int32 = ttl;
  Dart_CObject cobject_data;
  cobject_data.type = Dart_CObject_kTypedData;
  cobject_data.value.as_typed_data.length = rdlen;
  cobject_data.value.as_typed_data.type = Dart_TypedData_kUint8;
  cobject_data.value.as_typed_data.values =
      const_cast<uint8_t*>(reinterpret_cast<const uint8_t*>(rdata));
  Dart_CObject cobject_result;
  cobject_result.type = Dart_CObject_kArray;
  Dart_CObject* result_array[] =
      {&cobject_fullname, &cobject_type, &cobject_ttl, &cobject_data};
  cobject_result.value.as_array.length = 4;
  cobject_result.value.as_array.values = result_array;
  Dart_PostCObject(ctx->port, &cobject_result);
}

// Lookup request from Dart.
void HandleLookup(Dart_Port port_id, int type, char* fullname, int timeout) {
  DNSServiceRef ref;
  DNSServiceErrorType result;
  struct Context* context =
      reinterpret_cast<struct Context*>(malloc(sizeof(struct Context)));
  result = DNSServiceQueryRecord(&ref,
                                 0,
                                 0,
                                 fullname,
                                 type,
                                 kDNSServiceClass_IN,
                                 &QueryRecordCallback,
                                 context);
  if (result != kDNSServiceErr_NoError) {
    fprintf(stderr, "Error from DNSServiceQueryRecord: %d\n", result);
  } else {
    // Start a thread for pumping the results.
    context->ref = ref;
    context->timeout = timeout;
    context->port = port_id;
    StartThread(context);
  }
}

#endif
