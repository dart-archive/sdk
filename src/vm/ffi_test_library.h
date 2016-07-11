// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Header for testing library for testing the foreign function interface.
// There are no tests in this file, but we keep this to have a single place
// for functionality that we want to test in the FFI implementation.

#ifndef SRC_VM_FFI_TEST_LIBRARY_H_
#define SRC_VM_FFI_TEST_LIBRARY_H_

#include <stdint.h>

#ifdef _MSC_VER
// TODO(herhut): Do we need a __declspec here for Windows?
#define EXPORT
#else
#define EXPORT __attribute__((visibility("default")))
#endif

EXPORT int count;

EXPORT void setup();

EXPORT int getcount();

EXPORT void inc();

EXPORT int setcount(int val);

EXPORT int ifun0();

EXPORT int ifun1(int a);

EXPORT int ifun2(int a, int b);

EXPORT int ifun3(int a, int b, int c);

EXPORT int ifun4(int a, int b, int c, int d);

EXPORT int ifun5(int a, int b, int c, int d, int e);

EXPORT int ifun6(int a, int b, int c, int d, int e, int f);

EXPORT int ifun7(int a, int b, int c, int d, int e, int f, int g);

EXPORT int ifun0EINTR();

EXPORT int ifun1EINTR(int a);

EXPORT int ifun2EINTR(int a, int b);

EXPORT int ifun3EINTR(int a, int b, int c);

EXPORT int ifun4EINTR(int a, int b, int c, int d);

EXPORT int ifun5EINTR(int a, int b, int c, int d, int e);

EXPORT int ifun6EINTR(int a, int b, int c, int d, int e, int f);

EXPORT int ifun7EINTR(int a, int b, int c, int d, int e, int f, int g);


EXPORT int64_t i64fun0();

EXPORT int64_t i64fun1(int a);

EXPORT int64_t i64fun2(int a, int b);

EXPORT int64_t i64fun3(int a, int b, int c);

EXPORT int64_t i64fun4(int a, int b, int c, int d);

EXPORT int64_t i64fun5(int a, int b, int c, int d, int e);

EXPORT int64_t i64fun6(int a, int b, int c, int d, int e, int f);

EXPORT int64_t i64fun7(int a, int b, int c, int d, int e, int f, int g);

EXPORT int64_t mix32_64_64(int a, int64_t b, int64_t c);

EXPORT int64_t mix32_64_32(int a, int64_t b, int c);

EXPORT int64_t mix64_32_64(int64_t a, int b, int64_t c);

EXPORT float ffun0();

EXPORT float ffun1(float a0);

EXPORT float ffun2(float a0, float a1);

EXPORT float ffun3(float a0, float a1, float a2);

EXPORT float ffun4(float a0, float a1, float a2, float a3);

EXPORT float ffun5(float a0, float a1, float a2, float a3, float a4);

EXPORT float ffun6(float a0, float a1, float a2, float a3, float a4, float a5);

EXPORT float ffun7(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6);

EXPORT float ffun8(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7);

EXPORT float ffun9(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8);

EXPORT float ffun10(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9);

EXPORT float ffun11(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10);

EXPORT float ffun12(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11);

EXPORT float ffun13(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12);

EXPORT float ffun14(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13);

EXPORT float ffun15(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14);

EXPORT float ffun16(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14, float a15);

EXPORT float ffun17(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14, float a15, float a16);

EXPORT double dfun0();

EXPORT double dfun1(double a0);

EXPORT double dfun2(double a0, double a1);

EXPORT double dfun3(double a0, double a1, double a2);

EXPORT double dfun4(double a0, double a1, double a2, double a3);

EXPORT double dfun5(double a0, double a1, double a2, double a3, double a4);

EXPORT double dfun6(double a0, double a1, double a2, double a3, double a4,
  double a5);

EXPORT double dfun7(double a0, double a1, double a2, double a3, double a4,
  double a5, double a6);

EXPORT double dfun8(double a0, double a1, double a2, double a3, double a4,
  double a5, double a6, double a7);

EXPORT double dfun9(double a0, double a1, double a2, double a3, double a4,
  double a5, double a6, double a7, double a8);

EXPORT double mixfp2(float a0, double a1);

EXPORT double mixfp3(float a0, double a1, float a2);

EXPORT double mixfp4(float a0, double a1, float a2, double a3);

EXPORT double mixfp5(float a0, double a1, float a2, double a3, float a4);

EXPORT double mixfp6(float a0, double a1, float a2, double a3, float a4,
  double a5);

EXPORT double mixfp7(float a0, double a1, float a2, double a3, float a4,
  double a5, float a6);

EXPORT double mixfp8(float a0, double a1, float a2, double a3, float a4,
  double a5, float a6, double a7);

EXPORT double mixfp9(float a0, double a1, float a2, double a3, float a4,
  double a5, float a6, double a7, float a8);

EXPORT double mixfp10(float a0, double a1, float a2, double a3, float a4,
  double a5, float a6, double a7, float a8, double a9);

EXPORT double mixfp11(float a0, double a1, float a2, double a3, float a4,
  double a5, float a6, double a7, float a8, double a9, float a10);

EXPORT double mixfp12(float a0, double a1, float a2, double a3, float a4,
  double a5, float a6, double a7, float a8, double a9, float a10, double a11);

EXPORT double mixfp13(float a0, double a1, float a2, double a3, float a4,
  double a5, float a6, double a7, float a8, double a9, float a10, double a11,
  float a12);

EXPORT float i5f17(int i0, int i1, int i2, int i3, int i4,
  float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14, float a15, float a16);

EXPORT float f17i5(float a0, float a1, float a2, float a3, float a4, float a5,
  float a6, float a7, float a8, float a9, float a10, float a11, float a12,
  float a13, float a14, float a15, float a16,
  int i0, int i1, int i2, int i3, int i4);

EXPORT void vfun0();

EXPORT void vfun1(int a);

EXPORT void vfun2(int a, int b);

EXPORT void vfun3(int a, int b, int c);

EXPORT void vfun4(int a, int b, int c, int d);

EXPORT void vfun5(int a, int b, int c, int d, int e);

EXPORT void vfun6(int a, int b, int c, int d, int e, int f);

EXPORT void vfun7(int a, int b, int c, int d, int e, int f, int g);

// We assume int are 32 bits, short is 16 bits, char is 8 bits,
// float is 32 bits, double is 64 bits.
EXPORT void* pfun0();

EXPORT void* pfun1(int value);

EXPORT void* pfun2(int value, int value2);

EXPORT void* pfun3(int value, int value2, int value3);

EXPORT void* pfun4(int value, int value2, int value3, int value4);

EXPORT void* pfun5(int value, int value2, int value3, int value4, int value5);

EXPORT void* pfun6(int value, int value2, int value3, int value4, int value5,
                   int value6);

EXPORT void* memint8();

EXPORT void* memint16();

EXPORT void* memuint16();

EXPORT void* memuint32();

EXPORT void* memint64();

EXPORT void* memuint64();

EXPORT void* memfloat32();

EXPORT void* memfloat64();

EXPORT void* memstring();

EXPORT int bufferRead(char* buffer);

EXPORT int bufferWrite(char* buffer, int value);

EXPORT intptr_t things;

EXPORT void* make_a_thing(void);

EXPORT void* make_b_thing(void);

EXPORT void free_thing(void* thing);

EXPORT intptr_t get_things();

EXPORT void* trampoline0(void* f);

EXPORT void* trampoline1(void* f, void* x);

EXPORT void* trampoline2(void* f, void* x, void* y);

EXPORT void* trampoline3(void* f, void* x, void* y, void* z);

EXPORT void* echoWord(void* x);

#endif  // SRC_VM_FFI_TEST_LIBRARY_H_
