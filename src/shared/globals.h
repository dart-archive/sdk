// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_GLOBALS_H_
#define SRC_SHARED_GLOBALS_H_

#ifndef __STDC_FORMAT_MACROS
#define __STDC_FORMAT_MACROS
#endif

#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS
#endif

#include <inttypes.h>
#include <limits.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

// Types for native machine words. Guaranteed to be able to hold
// pointers and integers.
#if defined(DARTINO64) && defined(DARTINO_TARGET_OS_WIN)
typedef long long word;            // NOLINT
typedef unsigned long long uword;  // NOLINT
#define WORD_C(n) n##LL
#define UWORD_C(n) n##LL
#else
typedef long word;            // NOLINT
typedef unsigned long uword;  // NOLINT
#define WORD_C(n) n##L
#define UWORD_C(n) n##UL
#endif

// Introduce integer types with specific bit widths.
typedef signed char int8;
typedef short int16;  // NOLINT
typedef int int32;

typedef unsigned char uint8;
typedef unsigned short uint16;  // NOLINT
typedef unsigned int uint32;

// On Windows platforms, long is always 32 bit.
#if defined(DARTINO64) && !defined(DARTINO_TARGET_OS_WIN)
typedef long int64;            // NOLINT
typedef unsigned long uint64;  // NOLINT
#else
typedef long long int int64;        // NOLINT
typedef long long unsigned uint64;  // NOLINT
#endif

#ifdef DARTINO_USE_SINGLE_PRECISION
typedef float dartino_double;
typedef uint32 dartino_double_as_uint;
#else
typedef double dartino_double;
typedef uint64 dartino_double_as_uint;
#endif

// Byte sizes.
const int kWordSize = sizeof(word);
const int kDoubleSize = sizeof(double);  // NOLINT
const int kPointerSize = sizeof(void*);  // NOLINT
const int kDartinoDoubleSize = sizeof(dartino_double);

#ifdef DARTINO64
const int kPointerSizeLog2 = 3;
const int kAlternativePointerSize = 4;
#else
const int kPointerSizeLog2 = 2;
const int kAlternativePointerSize = 8;
#endif

// Bit sizes.
const int kBitsPerByte = 8;
const int kBitsPerByteLog2 = 3;
const int kBitsPerPointer = kPointerSize * kBitsPerByte;
const int kBitsPerWord = kWordSize * kBitsPerByte;
const int kBitsPerDartinoDouble = kDartinoDoubleSize * kBitsPerByte;

// System-wide named constants.
const int KB = 1024;
const int MB = KB * KB;
const int GB = KB * KB * KB;

#if __BYTE_ORDER != __LITTLE_ENDIAN
#error "Only little endian hosts are supported"
#endif

// A macro to disallow the copy constructor and operator= functions.
// This should be used in the private: declarations for a class.
#define DISALLOW_COPY_AND_ASSIGN(TypeName) \
  TypeName(const TypeName&);               \
  void operator=(const TypeName&)

// A macro to disallow all the implicit constructors, namely the default
// constructor, copy constructor and operator= functions. This should be
// used in the private: declarations for a class that wants to prevent
// anyone from instantiating it. This is especially useful for classes
// containing only static methods.
#define DISALLOW_IMPLICIT_CONSTRUCTORS(TypeName) \
  TypeName();                                    \
  DISALLOW_COPY_AND_ASSIGN(TypeName)

// Macro to disallow allocation in the C++ heap. This should be used
// in the private section for a class.
#define DISALLOW_ALLOCATION()      \
  void* operator new(size_t size); \
  void operator delete(void* pointer)

// The expression ARRAY_SIZE(array) is a compile-time constant of type
// size_t which represents the number of elements of the given
// array. You should only use ARRAY_SIZE on statically allocated
// arrays.
#define ARRAY_SIZE(array)               \
  ((sizeof(array) / sizeof(*(array))) / \
  static_cast<size_t>(!(sizeof(array) % sizeof(*(array)))))

// The USE(x) template is used to silence C++ compiler warnings issued
// for unused variables.
template <typename T>
static inline void USE(T) {}

// The type-based aliasing rule allows the compiler to assume that
// pointers of different types (for some definition of different)
// never alias each other. Thus the following code does not work:
//
// float f = foo();
// int fbits = *(int*)(&f);
//
// The compiler 'knows' that the int pointer can't refer to f since
// the types don't match, so the compiler may cache f in a register,
// leaving random data in fbits.  Using C++ style casts makes no
// difference, however a pointer to char data is assumed to alias any
// other pointer. This is the 'memcpy exception'.
//
// The bit_cast function uses the memcpy exception to move the bits
// from a variable of one type to a variable of another type. Of
// course the end result is likely to be implementation dependent.
// Most compilers (gcc-4.2 and MSVC 2005) will completely optimize
// bit_cast away.
//
// There is an additional use for bit_cast. Recent gccs will warn when
// they see casts that may result in breakage due to the type-based
// aliasing rule. If you have checked that there is no breakage you
// can use bit_cast to cast one pointer type to another. This confuses
// gcc enough that it can no longer see that you have cast one pointer
// type to another thus avoiding the warning.
template <class D, class S>
inline D bit_cast(const S& source) {
  // Compile time assertion: sizeof(D) == sizeof(S). A compile error
  // here means your D and S have different sizes.
  char VerifySizesAreEqual[sizeof(D) == sizeof(S) ? 1 : -1];
  USE(VerifySizesAreEqual);

  D destination;
  memcpy(&destination, &source, sizeof(destination));
  return destination;
}

#ifdef __has_builtin
#define DARTINO_HAS_BUILTIN_SADDL_OVERFLOW \
  (__has_builtin(__builtin_saddl_overflow))
#define DARTINO_HAS_BUILTIN_SSUBL_OVERFLOW \
  (__has_builtin(__builtin_ssubl_overflow))
#define DARTINO_HAS_BUILTIN_SMULL_OVERFLOW \
  (__has_builtin(__builtin_smull_overflow))
#endif

#ifdef TEMP_FAILURE_RETRY
#undef TEMP_FAILURE_RETRY
#endif
// The definition below is copied from Linux and adapted to avoid lint
// errors (type long int changed to intptr_t and do/while split on
// separate lines with body in {}s) and to also block signals.
#define TEMP_FAILURE_RETRY(expression)               \
  ({                                                 \
    intptr_t __result;                               \
    do {                                             \
      __result = (expression);                       \
    } while ((__result == -1L) && (errno == EINTR)); \
    __result;                                        \
  })

#define VOID_TEMP_FAILURE_RETRY(expression) \
  (static_cast<void>(TEMP_FAILURE_RETRY(expression)))

#endif  // SRC_SHARED_GLOBALS_H_
