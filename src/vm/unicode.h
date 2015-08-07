// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#ifndef SRC_VM_UNICODE_H_
#define SRC_VM_UNICODE_H_

#include "src/shared/assert.h"
#include "src/shared/globals.h"

namespace fletch {

class String;

class CodePointIterator {
 public:
  explicit CodePointIterator(String* str);

  int32 Current() const {
    ASSERT(index_ >= 0);
    ASSERT(index_ < end_);
    return ch_;
  }

  bool Next();

 private:
  String* str_;
  int32 ch_;
  word index_;
  word end_;
};

class Utf {
 public:
  static const int32 kMaxCodePoint = 0x10FFFF;

  static bool IsLatin1(int32 code_point) {
    return (code_point >= 0) && (code_point <= 0xFF);
  }

  static bool IsBmp(int32 code_point) {
    return (code_point >= 0) && (code_point <= 0xFFFF);
  }

  static bool IsSupplementary(int32 code_point) {
    return (code_point > 0xFFFF) && (code_point <= kMaxCodePoint);
  }

  // Returns true if the code point value is above Plane 17.
  static bool IsOutOfRange(word code_point) {
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

  static word Length(int32 ch);
  static word Length(String* str);

  static word Encode(int32 ch, char* dst);
  static word Encode(String* src, char* dst, word len);

  static const int32 kMaxOneByteChar   = 0x7F;
  static const int32 kMaxTwoByteChar   = 0x7FF;
  static const int32 kMaxThreeByteChar = 0xFFFF;
  static const int32 kMaxFourByteChar  = Utf::kMaxCodePoint;

 private:
  static bool IsTrailByte(uint8_t code_unit) {
    return (code_unit & 0xC0) == 0x80;
  }

  static bool IsNonShortestForm(uint32 code_point, size_t num_code_units) {
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
  static const uint32 kMagicBits[];
  static const uint32 kOverlongMinimum[];
};

class Utf16 {
 public:
  // Returns the length of the code point in UTF-16 code units.
  static word Length(int32 ch) {
    return (ch <= Utf16::kMaxCodeUnit) ? 1 : 2;
  }

  // Returns true if ch is a lead or trail surrogate.
  static bool IsSurrogate(int32 ch) {
    return (ch & 0xFFFFF800) == 0xD800;
  }

  // Returns true if ch is a lead surrogate.
  static bool IsLeadSurrogate(int32 ch) {
    return (ch & 0xFFFFFC00) == 0xD800;
  }

  // Returns true if ch is a low surrogate.
  static bool IsTrailSurrogate(int32 ch) {
    return (ch & 0xFFFFFC00) == 0xDC00;
  }

  // Returns the character at i and advances i to the next character
  // boundary.
  static int32 Next(const uint16_t* characters, word* i, word len) {
    int32 ch = characters[*i];
    if (Utf16::IsLeadSurrogate(ch) && (*i < (len - 1))) {
      int32 ch2 = characters[*i + 1];
      if (Utf16::IsTrailSurrogate(ch2)) {
        ch = Utf16::Decode(ch, ch2);
        *i += 1;
      }
    }
    *i += 1;
    return ch;
  }

  // Decodes a surrogate pair into a supplementary code point.
  static int32 Decode(int32 lead, int32 trail) {
    return 0x10000 + ((lead & 0x3FF) << 10) + (trail & 0x3FF);
  }

  // Encodes a single code point.
  static void Encode(int32 codepoint, uint16_t* dst);

  static const int32 kMaxCodeUnit = 0xFFFF;

 private:
  static const int32 kLeadSurrogateOffset = (0xD800 - (0x10000 >> 10));

  static const int32 kSurrogateOffset = (0x10000 - (0xD800 << 10) - 0xDC00);
};

}  // namespace fletch

#endif  // SRC_VM_UNICODE_H_
