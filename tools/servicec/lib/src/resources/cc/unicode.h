// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#ifndef UNICODE_H_
#define UNICODE_H_

#include "struct.h"

class Utf {
 public:
  static const int32_t kMaxCodePoint = 0x10FFFF;

  static bool IsLatin1(int32_t code_point) {
    return (code_point >= 0) && (code_point <= 0xFF);
  }

  static bool IsBmp(int32_t code_point) {
    return (code_point >= 0) && (code_point <= 0xFFFF);
  }

  static bool IsSupplementary(int32_t code_point) {
    return (code_point > 0xFFFF) && (code_point <= kMaxCodePoint);
  }

  // Returns true if the code point value is above Plane 17.
  static bool IsOutOfRange(intptr_t code_point) {
    return (code_point < 0) || (code_point > kMaxCodePoint);
  }
};

class Utf8 {
 public:
  enum Type {
    kLatin1 = 0,  // Latin-1 code point [U+0000, U+00FF].
    kBMP,  // Basic Multilingual Plane code point [U+0000, U+FFFF].
    kSupplementary,  // Supplementary code point [U+010000, U+10FFFF].
  };

  // Returns the most restricted coding form in which the sequence of utf8
  // characters in 'utf8_array' can be represented in, and the number of
  // code units needed in that form.
  static intptr_t CodeUnitCount(const char* utf8_array,
                                intptr_t array_len,
                                Type* type);

  static intptr_t Length(int32_t ch);
  static intptr_t Length(List<uint16_t> str);

  static intptr_t Encode(int32_t ch, char* dst);
  static intptr_t Encode(List<uint16_t> str, char* dst, intptr_t len);

  static intptr_t Decode(const char* utf8_array,
                         intptr_t array_len,
                         int32_t* ch);
  static bool DecodeToUTF16(const char* utf8_array,
                            intptr_t array_len,
                            uint16_t* dst,
                            intptr_t len);

  static const int32_t kMaxOneByteChar   = 0x7F;
  static const int32_t kMaxTwoByteChar   = 0x7FF;
  static const int32_t kMaxThreeByteChar = 0xFFFF;
  static const int32_t kMaxFourByteChar  = Utf::kMaxCodePoint;

 private:
  static bool IsTrailByte(uint8_t code_unit) {
    return (code_unit & 0xC0) == 0x80;
  }

  static bool IsNonShortestForm(uint32_t code_point, size_t num_code_units) {
    return code_point < kOverlongMinimum[num_code_units];
  }

  static bool IsLatin1SequenceStart(uint8_t code_unit) {
    // Check if utf8 sequence is the start of a codepoint <= U+00FF
    return (code_unit <= 0xC3);
  }

  static bool IsSupplementarySequenceStart(uint8_t code_unit) {
    // Check if utf8 sequence is the start of a codepoint >= U+10000.
    return (code_unit >= 0xF0);
  }

  static const int8_t kTrailBytes[];
  static const uint32_t kMagicBits[];
  static const uint32_t kOverlongMinimum[];
};

class Utf16 {
 public:
  // Returns the length of the code point in UTF-16 code units.
  static intptr_t Length(int32_t ch) {
    return (ch <= Utf16::kMaxCodeUnit) ? 1 : 2;
  }

  // Returns true if ch is a lead or trail surrogate.
  static bool IsSurrogate(int32_t ch) {
    return (ch & 0xFFFFF800) == 0xD800;
  }

  // Returns true if ch is a lead surrogate.
  static bool IsLeadSurrogate(int32_t ch) {
    return (ch & 0xFFFFFC00) == 0xD800;
  }

  // Returns true if ch is a low surrogate.
  static bool IsTrailSurrogate(int32_t ch) {
    return (ch & 0xFFFFFC00) == 0xDC00;
  }

  // Returns the character at i and advances i to the next character
  // boundary.
  static int32_t Next(const uint16_t* characters, intptr_t* i, intptr_t len) {
    int32_t ch = characters[*i];
    if (Utf16::IsLeadSurrogate(ch) && (*i < (len - 1))) {
      int32_t ch2 = characters[*i + 1];
      if (Utf16::IsTrailSurrogate(ch2)) {
        ch = Utf16::Decode(ch, ch2);
        *i += 1;
      }
    }
    *i += 1;
    return ch;
  }

  // Decodes a surrogate pair into a supplementary code point.
  static int32_t Decode(int32_t lead, int32_t trail) {
    return 0x10000 + ((lead & 0x3FF) << 10) + (trail & 0x3FF);
  }

  // Encodes a single code point.
  static void Encode(int32_t codepoint, uint16_t* dst);

  static const int32_t kMaxCodeUnit = 0xFFFF;

 private:
  static const int32_t kLeadSurrogateOffset = (0xD800 - (0x10000 >> 10));

  static const int32_t kSurrogateOffset = (0x10000 - (0xD800 << 10) - 0xDC00);
};

#endif  // UNICODE_H_
