// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Header for testing library for testing the foreign function interface.
// There are no tests in this file, but we keep this to have a single place
// for functionality that we want to test in the FFI implementation.

#ifndef SRC_VM_FFI_TEST_LIBRARY_H_
#define SRC_VM_FFI_TEST_LIBRARY_H_

#define EXPORT __attribute__((visibility("default")))

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

EXPORT int ifun0EINTR();

EXPORT int ifun1EINTR(int a);

EXPORT int ifun2EINTR(int a, int b);

EXPORT int ifun3EINTR(int a, int b, int c);

EXPORT int ifun4EINTR(int a, int b, int c, int d);

EXPORT int ifun5EINTR(int a, int b, int c, int d, int e);

EXPORT int ifun6EINTR(int a, int b, int c, int d, int e, int f);

EXPORT void vfun0();

EXPORT void vfun1(int a);

EXPORT void vfun2(int a, int b);

EXPORT void vfun3(int a, int b, int c);

EXPORT void vfun4(int a, int b, int c, int d);

EXPORT void vfun5(int a, int b, int c, int d, int e);

EXPORT void vfun6(int a, int b, int c, int d, int e, int f);

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

#endif  // SRC_VM_FFI_TEST_LIBRARY_H_
