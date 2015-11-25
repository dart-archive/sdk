// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Testing library for testing the foreign function interface.
// There are no tests in this file, but we keep this to have a single place
// for functionality that we want to test in the FFI implementation.

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "ffi_test_library.h"

// Copied from globals.h to have consistent values
// TODO(ricow): we could split globals into a c only part and a c++ part.
typedef signed char int8;
typedef short int16;  // NOLINT
typedef int int32;

typedef unsigned char uint8;
typedef unsigned short uint16;  // NOLINT
typedef unsigned int uint32;

#ifdef FLETCH64
typedef long int64;  // NOLINT
typedef unsigned long uint64;  // NOLINT
typedef char foobar;
#else
typedef long long int int64;  // NOLINT
typedef long long unsigned uint64;
typedef int foobar;
#endif

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

// We assume int are 32 bits, short is 16 bits, char is 8 bits,
// float is 32 bits, double is 64 bits.
void* pfun0() {
  int32* data = malloc(sizeof(int32) * 4);
  *data = 1;
  *(data + 1) = 2;
  *(data + 2) = 3;
  *(data + 3) = 4;
  return data;
}

void* pfun1(int value) {
  int32* data = malloc(sizeof(int32) * 4);
  *data = value;
  *(data + 1) = value;
  *(data + 2) = value;
  *(data + 3) = value;
  return data;
}

void* pfun2(int value, int value2) {
  int32* data = malloc(sizeof(int32) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value;
  *(data + 3) = value2;
  return data;
}

void* pfun3(int value, int value2, int value3) {
  int32* data = malloc(sizeof(int32) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value3;
  *(data + 3) = value2;
  return data;
}

void* pfun4(int value, int value2, int value3, int value4) {
  int32* data = malloc(sizeof(int32) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value3;
  *(data + 3) = value4;
  return data;
}

void* pfun5(int value, int value2, int value3, int value4, int value5) {
  int32* data = malloc(sizeof(int32) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value3;
  *(data + 3) = value4 + value5;
  return data;
}

void* pfun6(int value, int value2, int value3, int value4, int value5,
            int value6) {
  int32* data = malloc(sizeof(int32) * 4);
  *data = value;
  *(data + 1) = value2;
  *(data + 2) = value3;
  *(data + 3) = value4 + value5 + value6;
  return data;
}


void* memint8() {
  int8* data = malloc(sizeof(int8) * 4);
  *data = -1;
  *(data + 1) = -128;
  *(data + 2) = 'c';
  *(data + 3) = 'd';
  return data;
}

void* memint16() {
  int16* data = malloc(sizeof(int16) * 4);
  *data = 32767;
  *(data + 1) = -32768;
  *(data + 2) = 0;
  *(data + 3) = -1;
  return data;
}

void* memuint16() {
  uint16* data = malloc(sizeof(uint16) * 4);
  *data = 0;
  *(data + 1) = 32767;
  *(data + 2) = 32768;
  *(data + 3) = 65535;
  return data;
}

void* memuint32() {
  uint32* data = malloc(sizeof(uint32) * 4);
  *data = 0;
  *(data + 1) = 1;
  *(data + 2) = 65536;
  *(data + 3) = 4294967295u;
  return data;
}

void* memint64() {
  int64* data = malloc(sizeof(int64) * 4);
  *data = 0;
  *(data + 1) = -1;
  *(data + 2) = 9223372036854775807u;
  *(data + 3) = -9223372036854775808u;
  return data;
}

void* memuint64() {
  uint64* data = malloc(sizeof(uint64) * 4);
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
