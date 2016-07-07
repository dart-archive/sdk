// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Testing library for testing the foreign function interface.
// There are no tests in this file, but we keep this to have a single place
// for functionality that we want to test in the FFI implementation.

#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "ffi_test_library.h"


void setup() {
  count = 0;
}

int getcount() {
  return count;
}

void inc() {
  count++;
}

int setcount(int val) {
  count = val;
  return count;
}

int ifun0() {
  return 0;
}

int ifun1(int a) {
  return a;
}

int ifun2(int a, int b) {
  return a + b;
}

int ifun3(int a, int b, int c) {
  return a + b + c;
}

int ifun4(int a, int b, int c, int d) {
  return a + b + c + d;
}

int ifun5(int a, int b, int c, int d, int e) {
  return a + b + c + d + e;
}

int ifun6(int a, int b, int c, int d, int e, int f) {
  return a + b + c + d + e + f;
}

int ifun7(int a, int b, int c, int d, int e, int f, int g) {
  return a + b + c + d + e + f + g;
}

int ifun0EINTR() {
  static int count = 0;
  if (count++ < 10) {
    errno = EINTR;
    return -1;
  }
  return 0;
}

int ifun1EINTR(int a) {
  static int count = 0;
  if (count++ < 10) {
    errno = EINTR;
    return -1;
  }
  return a;
}

int ifun2EINTR(int a, int b) {
  static int count = 0;
  if (count++ < 10) {
    errno = EINTR;
    return -1;
  }
  return a + b;
}

int ifun3EINTR(int a, int b, int c) {
  static int count = 0;
  if (count++ < 10) {
    errno = EINTR;
    return -1;
  }
  return a + b + c;
}

int ifun4EINTR(int a, int b, int c, int d) {
  static int count = 0;
  if (count++ < 10) {
    errno = EINTR;
    return -1;
  }
  return a + b + c + d;
}

int ifun5EINTR(int a, int b, int c, int d, int e) {
  static int count = 0;
  if (count++ < 10) {
    errno = EINTR;
    return -1;
  }
  return a + b + c + d + e;
}

int ifun6EINTR(int a, int b, int c, int d, int e, int f) {
  static int count = 0;
  if (count++ < 10) {
    errno = EINTR;
    return -1;
  }
  return a + b + c + d + e + f;
}

int ifun7EINTR(int a, int b, int c, int d, int e, int f, int g) {
  static int count = 0;
  if (count++ < 10) {
    errno = EINTR;
    return -1;
  }
  return a + b + c + d + e + f + g;
}

int64_t i64fun1(int a) {
  return a;
}

int64_t i64fun2(int a, int b) {
  return a + b;
}

int64_t i64fun3(int a, int b, int c) {
  return a + b + c;
}

int64_t i64fun4(int a, int b, int c, int d) {
  return a + b + c + d;
}

int64_t i64fun5(int a, int b, int c, int d, int e) {
  return a + b + c + d + e;
}

int64_t i64fun6(int a, int b, int c, int d, int e, int f) {
  return a + b + c + d + e + f;
}

int64_t i64fun7(int a, int b, int c, int d, int e, int f, int g) {
  return a + b + c + d + e + f + g;
}

void vfun0() {
  count = 0;
}

void vfun1(int a) {
  count = 1;
}

void vfun2(int a, int b) {
  count = 2;
}

void vfun3(int a, int b, int c) {
  count = 3;
}

void vfun4(int a, int b, int c, int d) {
  count = 4;
}

void vfun5(int a, int b, int c, int d, int e) {
  count = 5;
}

void vfun6(int a, int b, int c, int d, int e, int f) {
  count = 6;
}

void vfun7(int a, int b, int c, int d, int e, int f, int g) {
  count = 7;
}

// We assume int are 32 bits, short is 16 bits, char is 8 bits,
// float is 32 bits, double is 64 bits.
void* pfun0() {
  int32_t* data = malloc(sizeof(int32_t) * 4);
  *data = 1;
  *(data + 1) = 2;
  *(data + 2) = 3;
  *(data + 3) = 4;
  return data;
}

void* pfun1(int value) {
  int32_t* data = malloc(sizeof(int32_t) * 4);
  *data = value;
  *(data + 1) = value;
  *(data + 2) = value;
  *(data + 3) = value;
  return data;
}

void* pfun2(int value, int value2) {
  int32_t* data = malloc(sizeof(int32_t) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value;
  *(data + 3) = value2;
  return data;
}

void* pfun3(int value, int value2, int value3) {
  int32_t* data = malloc(sizeof(int32_t) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value3;
  *(data + 3) = value2;
  return data;
}

void* pfun4(int value, int value2, int value3, int value4) {
  int32_t* data = malloc(sizeof(int32_t) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value3;
  *(data + 3) = value4;
  return data;
}

void* pfun5(int value, int value2, int value3, int value4, int value5) {
  int32_t* data = malloc(sizeof(int32_t) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value3;
  *(data + 3) = value4 + value5;
  return data;
}

void* pfun6(int value, int value2, int value3, int value4, int value5,
            int value6) {
  int32_t* data = malloc(sizeof(int32_t) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value3;
  *(data + 3) = value4 + value5 + value6;
  return data;
}

int64_t mix32_64_64(int a, int64_t b, int64_t c) {
  return a + b + c;
}

int64_t mix32_64_32(int a, int64_t b, int c) {
  return  a + b + c;
}

int64_t mix64_32_64(int64_t a, int b, int64_t c) {
  return  a + b + c;
}

float ffun0() {
  return 0.0;
}

float ffun1(float a0) {
  return a0;
}

float ffun2(float a0, float a1) {
  return a0 + a1;
}

float ffun3(float a0, float a1, float a2) {
  return a0 + a1 + a2;
}

float ffun4(float a0, float a1, float a2, float a3) {
  return a0 + a1 + a2 + a3;
}

float ffun5(float a0, float a1, float a2, float a3, float a4) {
  return a0 + a1 + a2 + a3 + a4;
}

float ffun6(float a0, float a1, float a2, float a3, float a4, float a5) {
  return a0 + a1 + a2 + a3 + a4 + a5;
}

float ffun7(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6;
}

float ffun8(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
}

float ffun9(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
}

float ffun10(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9;
}

float ffun11(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10;
}

float ffun12(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11;
}

float ffun13(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + 
    a10 + a11 + a12;
}

float ffun14(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + 
    a10 + a11 + a12 + a13;
}

float ffun15(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + 
    a10 + a11 + a12 + a13 + a14;
}

float ffun16(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14, float a15) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + 
    a10 + a11 + a12 + a13 + a14 + a15;
}

float ffun17(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14, float a15, float a16) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + 
    a10 + a11 + a12 + a13 + a14 + a15 + a16;
}

double dfun0() {
  return 0.0;
}

double dfun1(double a0) {
  return a0;
}

double dfun2(double a0, double a1) {
  return a0 + a1;
}

double dfun3(double a0, double a1, double a2) {
  return a0 + a1 + a2;
}

double dfun4(double a0, double a1, double a2, double a3) {
  return a0 + a1 + a2 + a3;
}

double dfun5(double a0, double a1, double a2, double a3, double a4) {
  return a0 + a1 + a2 + a3 + a4;
}

double dfun6(double a0, double a1, double a2, double a3, double a4, double a5) {
  return a0 + a1 + a2 + a3 + a4 + a5;
}

double dfun7(double a0, double a1, double a2, double a3, double a4, double a5,
  double a6) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6;
}

double dfun8(double a0, double a1, double a2, double a3, double a4, double a5,
  double a6, double a7) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
}

double dfun9(double a0, double a1, double a2, double a3, double a4, double a5,
  double a6, double a7, double a8) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
}

double mixfp2(float a0, double a1) {
  return a0 + a1;
}

double mixfp3(float a0, double a1, float a2) {
  return a0 + a1 + a2;
}

double mixfp4(float a0, double a1, float a2, double a3) {
  return a0 + a1 + a2 + a3;
}

double mixfp5(float a0, double a1, float a2, double a3, float a4) {
  return a0 + a1 + a2 + a3 + a4;
}

double mixfp6(float a0, double a1, float a2, double a3, float a4, double a5) {
  return a0 + a1 + a2 + a3 + a4 + a5;
}

double mixfp7(float a0, double a1, float a2, double a3, float a4, double a5,
  float a6) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6;
}

double mixfp8(float a0, double a1, float a2, double a3, float a4, double a5,
  float a6, double a7) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
}

double mixfp9(float a0, double a1, float a2, double a3, float a4, double a5,
  float a6, double a7, float a8) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
}

double mixfp10(float a0, double a1, float a2, double a3, float a4, double a5,
  float a6, double a7, float a8, double a9) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9;
}

double mixfp11(float a0, double a1, float a2, double a3, float a4, double a5,
  float a6, double a7, float a8, double a9, float a10) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10;
}

double mixfp12(float a0, double a1, float a2, double a3, float a4, double a5,
  float a6, double a7, float a8, double a9, float a10, double a11) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11;
}

double mixfp13(float a0, double a1, float a2, double a3, float a4, double a5,
  float a6, double a7, float a8, double a9, float a10, double a11, float a12) {
  return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11 + a12;
}

float i5f17(int i0, int i1, int i2, int i3, int i4, 
  float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14, float a15, float a16) {
  return i0 + i1 + i2 + i3 + i4 + a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 +
   a8 + a9 + a10 + a11 + a12 + a13 + a14 + a15 + a16;
}

float f17i5(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14, float a15, float a16, 
  int i0, int i1, int i2, int i3, int i4) {
  return i0 + i1 + i2 + i3 + i4 + a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 +
   a8 + a9 + a10 + a11 + a12 + a13 + a14 + a15 + a16;
}


void* memint8() {
  int8_t* data = malloc(sizeof(int8_t) * 4);
  *data = -1;
  *(data + 1) = -128;
  *(data + 2) = 'c';
  *(data + 3) = 'd';
  return data;
}

void* memint16() {
  int16_t* data = malloc(sizeof(int16_t) * 4);
  *data = 32767;
  *(data + 1) = -32768;
  *(data + 2) = 0;
  *(data + 3) = -1;
  return data;
}

void* memuint16() {
  uint16_t* data = malloc(sizeof(uint16_t) * 4);
  *data = 0;
  *(data + 1) = 32767;
  *(data + 2) = 32768;
  *(data + 3) = 65535;
  return data;
}

void* memuint32() {
  uint32_t* data = malloc(sizeof(uint32_t) * 4);
  *data = 0;
  *(data + 1) = 1;
  *(data + 2) = 65536;
  *(data + 3) = 4294967295u;
  return data;
}

void* memint64() {
  int64_t* data = malloc(sizeof(int64_t) * 4);
  *data = 0;
  *(data + 1) = -1;
  *(data + 2) = 9223372036854775807u;
  *(data + 3) = -9223372036854775808u;
  return data;
}

void* memuint64() {
  uint64_t* data = malloc(sizeof(uint64_t) * 4);
  *data = 0;
  *(data + 1) = 1;
  *(data + 2) = 2;
  *(data + 3) = 18446744073709551615u;
  return data;
}

void* memfloat32() {
  float* data = malloc(sizeof(float) * 4);
  *data = 0.0;
  *(data + 1) = 1.175494e-38f;
  *(data + 2) = 3.402823e+38f;
  *(data + 3) = 4;
  return data;
}

void* memfloat64() {
  double* data = malloc(sizeof(double) * 4);
  *data = 0.0;
  *(data + 1) = 1.79769e+308;
  *(data + 2) = -1.79769e+308;
  *(data + 3) = 4;
  return data;
}

void* memstring() {
  return strdup("dart");
}

// Used for testing our circular buffer, we just read or write one byte here
// and return it back to dart for validation.
// The buffer has the head as a 4 byte integer in the first 4 bytes, the
// tail as the next 4 bytes, and the size as the next 4 bytes.
// Data is following that.
// We don't do overflow checks here.
const int kHeadIndex = 0;  // Must be consistent with the dart implementation.
const int kTailIndex = 4;  // Must be consistent with the dart implementation.
const int kSizeIndex = 8;  // Must be consistent with the dart implementation.
const int kDataIndex = 12; // Must be consistent with the dart implementation.
int bufferRead(char* buffer) {
  uint32_t* size_pointer = (uint32_t*)(buffer + kSizeIndex);
  uint32_t size = *size_pointer;
  int* tail_pointer = (int*)(buffer + kTailIndex);
  int tail = *tail_pointer;
  char* value_pointer = buffer + kDataIndex + tail;
  int value = *value_pointer;
  *tail_pointer = (tail + 1) % size;
  return value;
}

int bufferWrite(char* buffer, int value) {
  uint32_t* size_pointer = (uint32_t*)(buffer + kSizeIndex);
  uint32_t size = *size_pointer;
  int* head_pointer = (int*)buffer;
  int head = *head_pointer;
  char* value_pointer = buffer + kDataIndex + head;
  *value_pointer = value;
  *head_pointer = (head + 1) % size;
  return value;
}

void* make_a_thing() {
  things |= 2;
  return (void*)(2);
}

void* make_b_thing() {
  things |= 1;
  return (void*)(1);
}

void free_thing(void* thing) {
  things ^= (intptr_t)(thing);
}

intptr_t get_things() {
  return things;
}

typedef void* (*Arity0)();
typedef void* (*Arity1)(void* x);
typedef void* (*Arity2)(void* x, void* y);
typedef void* (*Arity3)(void* x, void* y, void* z);

void* trampoline0(void* f) {
  void* result = ((Arity0)f)();
  return result;
}

void* trampoline1(void* f, void* x) {
  void* result = ((Arity1)f)(x);
  return result;
}

void* trampoline2(void* f, void* x, void* y) {
  void* result = ((Arity2)f)(x, y);
  return result;
}

void* trampoline3(void* f, void* x, void* y, void* z) {
  void* result = ((Arity3)f)(x, y, z);
  return result;
}

void* echoWord(void* x) {
  return x;
}
