// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Header for testing library for testing the foreign function interface.
// There are no tests in this file, but we keep this to have a single place
// for functionality that we want to test in the FFI implementation.

static int count;

void setup();

int getcount();

void inc();

int setcount(int val);

int ifun0();

int ifun1(int a);

int ifun2(int a, int b);

int ifun3(int a, int b, int c);

int ifun4(int a, int b, int c, int d);

int ifun5(int a, int b, int c, int d, int e);

int ifun6(int a, int b, int c, int d, int e, int f);

void vfun0();

void vfun1(int a);

void vfun2(int a, int b);

void vfun3(int a, int b, int c);

void vfun4(int a, int b, int c, int d);

void vfun5(int a, int b, int c, int d, int e);

void vfun6(int a, int b, int c, int d, int e, int f);

// We assume int are 32 bits, short is 16 bits, char is 8 bits,
// float is 32 bits, double is 64 bits.
void* pfun0();

void* pfun1(int value);

void* pfun2(int value, int value2);

void* pfun3(int value, int value2, int value3);

void* pfun4(int value, int value2, int value3, int value4);

void* pfun5(int value, int value2, int value3, int value4, int value5);

void* pfun6(int value, int value2, int value3, int value4, int value5,
            int value6);


void* memint8();

void* memint16();

void* memuint16();

void* memuint32();

void* memint64();

void* memuint64();

void* memfloat32();

void* memfloat64();
