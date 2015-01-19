// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_SCANNER_H_
#define SRC_COMPILER_SCANNER_H_

#include "src/compiler/builder.h"
#include "src/compiler/list.h"
#include "src/compiler/list_builder.h"
#include "src/compiler/tokens.h"
#include "src/compiler/trie.h"
#include "src/compiler/zone.h"

namespace fletch {

class Scanner : public StackAllocated {
 public:
  Scanner(Builder* builder, Zone* zone);
  void Scan(const char* input, Location start_location);

  List<TokenInfo> EncodedTokens();

 private:
  struct TokenBeginMarker {
    Token token;
    int pos;
  };

  Builder* const builder_;

  ListBuilder<TokenInfo, 1 * KB> tokens_;
  ListBuilder<TokenBeginMarker, 32> begin_marker_stack_;
  ListBuilder<char, 256> string_literal_buffer_;

  const char* input_;
  int index_;
  int begin_index_;
  Location start_location_;

  Builder* builder() const { return builder_; }

  inline int Advance() { return input_[++index_]; }
  inline int Peek(int offset = 1) { return input_[index_ + offset]; }

  bool ScanUntil(int end = 0);
  bool ScanToken();

  bool ScanNumber(int peek);
  bool ScanIdentifier(int peek, bool allow_dollar = true);
  bool ScanString(int peek, bool raw);

  void AddToken(Token token, int value = -1);

  void PushTokenBeginMarker(Token token);
  void PopTokenBeginMarker(Token token);

  // Create a new string token. If string_literal_buffer_ is not empty, the
  // string is created from that buffer. If it's empty, (start, end) is used to
  // greb a substring from the input.
  void NewString(Token token, int start, int end);

  inline bool ScanSingle(Token token);
  inline bool RecognizeSingle(int peek, Token token);

  void SkipWhitespace(int peek);
  bool SkipSinglelineComment(int peek);
  bool SkipMultilineComment(int peek);

  const char* AllocateTerminal(int start, int end);
};

class TokenStream : public StackAllocated {
 public:
  explicit TokenStream(List<TokenInfo> encoded)
      : encoded_(encoded)
      , position_(0) {
  }

  int position() const { return position_; }
  void RewindTo(int position) { position_ = position; }

  void Advance() { position_++; }
  void Skip(int n) { position_ += n; }

  Token Current() const {
    ASSERT(position_ < encoded_.length());
    return encoded_[position_].token();
  }

  int CurrentIndex() const {
    ASSERT(position_ < encoded_.length());
    return encoded_[position_].index();
  }

  Location CurrentLocation() const {
    ASSERT(position_ < encoded_.length());
    return encoded_[position_].location();
  }

 private:
  const List<TokenInfo> encoded_;
  int position_;
};

}  // namespace fletch

#endif  // SRC_COMPILER_SCANNER_H_
