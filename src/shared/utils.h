// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_UTILS_H_
#define SRC_SHARED_UTILS_H_

#include <cstdarg>
#include <cstdlib>

#include "src/shared/assert.h"
#include "src/shared/atomic.h"
#include "src/shared/globals.h"

namespace fletch {

class Mutex;

class PrintInterceptor {
public:
  PrintInterceptor() : next_(NULL) {}
  virtual ~PrintInterceptor() {
    delete next_;
    next_ = NULL;
  }
  virtual void Out(char* message) = 0;
  virtual void Error(char* message) = 0;
 private:
  friend class Print;
  PrintInterceptor* next_;
};

// All stdout and stderr output from the VM should go through this
// Print class in order to allow the output to be intercepted.
class Print {
public:
  static void Out(const char* format, ...);
  static void Error(const char* format, ...);
  static void RegisterPrintInterceptor(PrintInterceptor* interceptor);
  static void UnregisterPrintInterceptors();

  // Disable printing to stdout and stderr and only pass output
  // to print interceptors.
  static void DisableStandardOutput() { standard_output_enabled_ = false; }

private:
  static Mutex* mutex_;  // Mutex for interceptor modification and iteration.
  static PrintInterceptor* interceptor_;
  static Atomic<bool> standard_output_enabled_;
};

class Utils {
 public:
  template<typename T>
  static inline T Minimum(T x, T y) {
    return x < y ? x : y;
  }

  template<typename T>
  static inline T Maximum(T x, T y) {
    return x > y ? x : y;
  }

  template<typename T>
  static inline bool IsPowerOfTwo(T x) {
    return (x & (x - 1)) == 0;
  }

  template<typename T>
  static inline bool IsAligned(T x, int n) {
    ASSERT(IsPowerOfTwo(n));
    return ((x - static_cast<T>(0)) & (n - 1)) == 0;
  }

  template<typename T>
  static inline T RoundDown(T x, int n) {
    ASSERT(IsPowerOfTwo(n));
    return (x & -n);
  }

  template<typename T>
  static inline T RoundUp(T x, int n) {
    return RoundDown(x + n - 1, n);
  }

  // Implementation is from "Hacker's Delight" by Henry S. Warren, Jr.,
  // figure 3-3, page 48, where the function is called clp2.
  template<typename T>
  static inline T RoundUpToPowerOfTwo(T x) {
    x = x - 1;
    x = x | (x >> 1);
    x = x | (x >> 2);
    x = x | (x >> 4);
    x = x | (x >> 8);
    x = x | (x >> 16);
    return x + 1;
  }

  // Computes a hash value for the given string.
  static uint32 StringHash(const uint16* data, int length);

  // Bit width testers.
  static bool IsInt8(word value) {
    return (-128 <= value) && (value < 128);
  }

  static bool IsUint8(word value) {
    return (0 <= value) && (value < 256);
  }

  static bool IsInt16(word value) {
    return (-32768 <= value) && (value < 32768);
  }

  static bool IsUint16(word value) {
    return (0 <= value) && (value < 65536);
  }

#ifdef FLETCH64
  static bool IsInt32(word value) {
    return (-(1L << 31) <= value) && (value < (1L << 31));
  }

  static bool IsUint32(word value) {
    return (0 <= value) && (value < (1L << 32));
  }
#endif

  static bool SignedAddOverflow(word lhs, word rhs, word* val) {
#if FLETCH_HAS_BUILTIN_SADDL_OVERFLOW
    return __builtin_saddl_overflow(lhs, rhs, val);
#else
    uword res = static_cast<uword>(lhs) + static_cast<uword>(rhs);
    *val = bit_cast<uword>(res);
    return ((res ^ lhs) & (res ^ rhs) & (1UL << (kBitsPerWord - 1))) != 0;
#endif
  }

  static bool SignedSubOverflow(word lhs, word rhs, word* val) {
#if FLETCH_HAS_BUILTIN_SSUBL_OVERFLOW
    return __builtin_ssubl_overflow(lhs, rhs, val);
#else
    uword res = static_cast<uword>(lhs) - static_cast<uword>(rhs);
    *val = bit_cast<word>(res);
    return ((res ^ lhs) & (res ^ ~rhs) & (1UL << (kBitsPerWord - 1))) != 0;
#endif
  }

  static bool SignedMulOverflow(word lhs, word rhs, word* val) {
#if FLETCH_HAS_BUILTIN_SMULL_OVERFLOW
    return __builtin_smull_overflow(lhs, rhs, val);
#else
    // TODO(ajohnsen): This does now really work on x64.
    word res = lhs * rhs;
    bool overflow = (res != static_cast<int64>(lhs) * rhs);
    if (overflow) return true;
    *val = res;
    return false;
#endif
  }

  // Read a 32-bit integer from the buffer, as little endian.
  static inline int32 ReadInt32(uint8* buffer) {
    return reinterpret_cast<int32*>(buffer)[0];
  }

  // Write a 32-bit integer to the buffer, as little endian.
  static inline void WriteInt32(uint8* buffer, int32 value) {
    reinterpret_cast<int32*>(buffer)[0] = value;
  }

  // Read a 64-bit integer from the buffer, as little endian.
  static inline int64 ReadInt64(uint8* buffer) {
    return reinterpret_cast<int64*>(buffer)[0];
  }

  // Write a 64-bit integer to the buffer, as little endian.
  static inline void WriteInt64(uint8* buffer, int64 value) {
    reinterpret_cast<int64*>(buffer)[0] = value;
  }
};

// BitField is a template for encoding and decoding a bit field inside
// an unsigned machine word.
template<class T, int position, int size>
class BitField {
 public:
  // Tells whether the provided value fits into the bit field.
  static bool is_valid(T value) {
    return (static_cast<uword>(value) & ~((1U << size) - 1)) == 0;
  }

  // Returns a uword mask of the bit field.
  static uword mask() {
    return ((1U << size) - 1) << position;
  }

  // Returns the shift count needed to right-shift the bit field to
  // the least-significant bits.
  static int shift() {
    return position;
  }

  // Returns a uword with the bit field value encoded.
  static uword encode(T value) {
    ASSERT(is_valid(value));
    return static_cast<uword>(value) << position;
  }

  // Extracts the bit field from the value.
  static T decode(uword value) {
    return static_cast<T>((value >> position) & ((1U << size) - 1));
  }

  // Returns a uword with the bit field value encoded based on the
  // original value. Only the bits corresponding to this bit field
  // will be changed.
  static uword update(T value, uword original) {
    ASSERT(is_valid(value));
    return (static_cast<uword>(value) << position) | (~mask() & original);
  }
};

// BoolField is a template for encoding and decoding a bit inside an
// unsigned machine word.
template<int position>
class BoolField {
 public:
  // Returns a uword with the bool value encoded.
  static uword encode(bool value) {
    return static_cast<uword>((value ? 1U : 0) << position);
  }

  // Extracts the bool from the value.
  static bool decode(uword value) {
    return (value & (1U << position)) != 0;
  }

  // Returns a uword mask of the bit field.
  static uword mask() {
    return 1U << position;
  }

  // Returns a uword with the bool field value encoded based on the
  // original value. Only the single bit corresponding to this bool
  // field will be changed.
  static uword update(bool value, uword original) {
    const uword mask = 1U << position;
    return value ? original | mask : original & ~mask;
  }
};

}  // namespace fletch

#endif  // SRC_SHARED_UTILS_H_
