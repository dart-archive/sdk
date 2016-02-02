// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdbool.h>
#include <inttypes.h>

#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/error.h"
#include "mbedtls/certs.h"

// Size functions that we use to get the size of the structs for allocating
// memory.
int entropy_context_sizeof() {
  return sizeof(mbedtls_entropy_context);
}

int ssl_context_sizeof() {
  return sizeof(mbedtls_ssl_context);
}

int ctr_drbg_context_sizeof() {
  return sizeof(mbedtls_ctr_drbg_context);
}

int ssl_config_sizeof() {
  return sizeof(mbedtls_ssl_config);
}

int x509_crt_sizeof() {
  return sizeof(mbedtls_x509_crt);
}


// Support for passing around 2 circular buffers as the context.
// The context below is assumed to hold two circular buffer pointers.
// The context is passed by mbedtls to the dart_send and dart_recv functions
// when called.
const int kSendIndex = 0;
const int kRecvIndex = sizeof(void*);
char* get_send_buffer(void* ctx) {
  char** buffer_address = ((char**) ctx) + kSendIndex;
  return *buffer_address;
}

char* get_recv_buffer(void* ctx) {
  char** buffer_address = ((char**) ctx) + kRecvIndex;
  return *buffer_address;
}


// Code for circular buffer.
// TODO(ricow): move this to a seperate library that can be used in general.
const int kHeadIndex = 0;  // Must be consistent with the dart implementation.
const int kTailIndex = 4;  // Must be consistent with the dart implementation.
const int kSizeIndex = 8;  // Must be consistent with the dart implementation.
const int kDataIndex = 12; // Must be consistent with the dart implementation.

uint32_t get_size(char* buffer) {
  return *(uint32_t*)(buffer + kSizeIndex);
}

uint32_t get_tail(char* buffer) {
  return *(uint32_t*)(buffer + kTailIndex);
}

void set_tail(char* buffer, int value) {
  *(uint32_t*)(buffer + kTailIndex) =  value;
}

uint32_t get_head(char* buffer) {
  return *(uint32_t*)(buffer + kHeadIndex);
}

void set_head(char* buffer, int value) {
  *(int*)(buffer + kHeadIndex) = value;
}

bool is_full(char* buffer) {
  return ((get_head(buffer) + 1) % get_size(buffer)) == get_tail(buffer);
}

bool is_empty(char* buffer) {
  return get_head(buffer) == get_tail(buffer);
}

uint32_t get_available(char* buffer) {
  if (is_empty(buffer)) return 0;
  if (get_head(buffer) > get_tail(buffer)) {
    return get_head(buffer) - get_tail(buffer);
  }
  return  get_size(buffer) - get_tail(buffer) + get_head(buffer);
}

uint32_t get_free_space(char* buffer) {
  return get_size(buffer) - get_available(buffer) - 1;
}

uint32_t buffer_write(char* buffer, const unsigned char* buf, uint32_t len,
                      int on_full) {
  uint32_t free;
  uint32_t bytes;
  uint32_t head;
  uint32_t size;
  uint32_t written;

  if (is_full(buffer)) return on_full;
  free = get_free_space(buffer);
  bytes = free > len ? len : free;
  head = get_head(buffer);
  size = get_size(buffer);
  written = 0;
  while (written < bytes) {
    // TODO(ricow): consider using memmove here instead;
    char* value_pointer = buffer + kDataIndex + head;
    *value_pointer = buf[written];
    head = (head + 1) % size;
    written++;
  }
  set_head(buffer, head);
  return written;
}

size_t buffer_read(char* buffer, unsigned char* buf, size_t len,
                   int on_empty) {
  uint32_t available;
  uint32_t bytes;
  uint32_t tail;
  uint32_t size;
  uint32_t read;
  if (is_empty(buffer)) return on_empty;
  available = get_available(buffer);
  bytes = available > len ? len : available;
  tail = get_tail(buffer);
  size = get_size(buffer);
  read = 0;
  while (read < bytes) {
    char* value_pointer = buffer + kDataIndex + tail;
    *(buf + read) = *value_pointer;
    tail = (tail + 1) % size;
    read++;
  }
  set_tail(buffer, tail);
  return read;
}


// Send and recv functions. The functions simply write or read to our buffers
// and return the corresponting mbedtls want read/write in case the buffer is
// full/empty.
int dart_send(void *ctx, const unsigned char *buf, size_t len) {
  char *send_buffer = get_send_buffer(ctx);
  int written = buffer_write(send_buffer, buf, len, MBEDTLS_ERR_SSL_WANT_WRITE);
  return written;
}

int dart_recv(void *ctx, unsigned char *buf, size_t len) {
  char *recv_buffer = get_recv_buffer(ctx);
  int read = buffer_read(recv_buffer, buf, len, MBEDTLS_ERR_SSL_WANT_READ);
  return read;
}
