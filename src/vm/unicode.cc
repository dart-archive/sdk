// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#include "src/vm/unicode.h"

#include "src/shared/assert.h"

#include "src/vm/object.h"

namespace fletch {

const int8_t Utf8::kTrailBytes[256] = {
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 0, 0
};


const uint32_t Utf8::kMagicBits[7] = {
  0,  // Padding.
  0x00000000,
  0x00003080,
  0x000E2080,
  0x03C82080,
  0xFA082080,
  0x82082080
};


// Minimum values of code points used to check shortest form.
const uint32_t Utf8::kOverlongMinimum[7] = {
  0,  // Padding.
  0x0,
  0x80,
  0x800,
  0x10000,
  0xFFFFFFFF,
  0xFFFFFFFF
};

class CodePointIterator {
 public:
  explicit CodePointIterator(String* str)
      : str_(str),
        ch_(0),
        index_(-1),
        end_(str->length()) {
  }

  int32_t Current() const {
    ASSERT(index_ >= 0);
    ASSERT(index_ < end_);
    return ch_;
  }

  bool Next() {
    ASSERT(index_ >= -1);
    intptr_t length = Utf16::Length(ch_);
    if (index_ < (end_ - length)) {
      index_ += length;
      ch_ = str_->get_code_unit(index_);
      if (Utf16::IsLeadSurrogate(ch_) && (index_ < (end_ - 1))) {
        int32_t ch2 = str_->get_code_unit(index_ + 1);
        if (Utf16::IsTrailSurrogate(ch2)) {
          ch_ = Utf16::Decode(ch_, ch2);
        }
      }
      return true;
    }
    index_ = end_;
    return false;
  }

 private:
  String* str_;
  int32_t ch_;
  intptr_t index_;
  intptr_t end_;
};

intptr_t Utf8::Length(int32_t ch) {
  if (ch <= kMaxOneByteChar) {
    return 1;
  } else if (ch <= kMaxTwoByteChar) {
    return 2;
  } else if (ch <= kMaxThreeByteChar) {
    return 3;
  }
  ASSERT(ch <= kMaxFourByteChar);
  return 4;
}

intptr_t Utf8::Length(String* str) {
  intptr_t length = 0;
  CodePointIterator it(str);
  while (it.Next()) {
    int32_t ch = it.Current();
    length += Utf8::Length(ch);
  }
  return length;
}

intptr_t Utf8::Encode(int32_t ch, char* dst) {
  static const int kMask = ~(1 << 6);
  if (ch <= kMaxOneByteChar) {
    dst[0] = ch;
    return 1;
  }
  if (ch <= kMaxTwoByteChar) {
    dst[0] = 0xC0 | (ch >> 6);
    dst[1] = 0x80 | (ch & kMask);
    return 2;
  }
  if (ch <= kMaxThreeByteChar) {
    dst[0] = 0xE0 | (ch >> 12);
    dst[1] = 0x80 | ((ch >> 6) & kMask);
    dst[2] = 0x80 | (ch & kMask);
    return 3;
  }
  ASSERT(ch <= kMaxFourByteChar);
  dst[0] = 0xF0 | (ch >> 18);
  dst[1] = 0x80 | ((ch >> 12) & kMask);
  dst[2] = 0x80 | ((ch >> 6) & kMask);
  dst[3] = 0x80 | (ch & kMask);
  return 4;
}

intptr_t Utf8::Encode(String* src, char* dst, intptr_t len) {
  intptr_t pos = 0;
  CodePointIterator it(src);
  while (it.Next()) {
    int32_t ch = it.Current();
    intptr_t num_bytes = Utf8::Length(ch);
    if (pos + num_bytes > len) {
      break;
    }
    Utf8::Encode(ch, &dst[pos]);
    pos += num_bytes;
  }
  return pos;
}

}  // namespace fletch
