// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <errno.h>
#include <cstdlib>

#include "src/shared/assert.h"
#include "src/compiler/scanner.h"

namespace fletch {

inline bool IsNewline(int c) {
  return (c == 10) || (c == 13);
}

inline bool IsWhitespace(int c) {
  return (c == ' ') || IsNewline(c) || (c == '\t');
}

inline bool IsLetter(int c) {
  return (('A' <= c) && (c <= 'Z')) || (('a' <= c) && (c <= 'z'));
}

inline bool IsDecimalDigit(int c) {
  return ('0' <= c) && (c <= '9');
}

inline bool IsHexDigit(int c) {
  return IsDecimalDigit(c) ||
      (('A' <= c) && (c <= 'F')) ||
      (('a' <= c) && (c <= 'f'));
}

inline bool IsIdentifierStart(int c) {
  return IsLetter(c) || (c == '_') || (c == '$');
}

inline bool IsIdentifierPart(int c) {
  return IsIdentifierStart(c) || IsDecimalDigit(c);
}

inline bool IsStringStart(int c) {
  return (c == '\'') || (c == '"');
}

Scanner::Scanner(Builder* builder, Zone* zone)
    : builder_(builder)
    , tokens_(zone)
    , begin_marker_stack_(zone)
    , string_literal_buffer_(zone)
    , input_(NULL)
    , index_(-1) {
}

List<TokenInfo> Scanner::EncodedTokens() {
  input_ = NULL;
  return tokens_.ToList();
}

void Scanner::Scan(const char* input, Location start_location) {
  tokens_.Clear();
  ASSERT(input_ == NULL);
  input_ = input;
  index_ = 0;
  start_location_ = start_location;
  if (static_cast<uint8>(input_[index_]) == 0xef) {
    // UTF-8 BOM
    index_++;
    if (static_cast<uint8>(input_[index_++]) != 0xbb ||
        static_cast<uint8>(input_[index_++]) != 0xbf) {
      builder()->ReportError(start_location_, "Bad UTF-8 BOM");
    }
  }
  if (input_[index_] == '#') {
    int peek = Advance();
    while (peek != '\n' && peek != kEOF) {
      peek = Advance();
    }
    Advance();
  }
  while (ScanToken()) {
    // Keep going.
  }
  AddToken(kEOF);
}

bool Scanner::ScanUntil(int end) {
  while (true) {
    if (input_[index_] == end) break;
    if (!ScanToken()) return false;
  }
  return true;
}

bool Scanner::ScanToken() {
  begin_index_ = index_;
  int peek = input_[index_];
  switch (peek) {
    case 0:
      // End of file.
      return false;

    case 1:
    case 2:
    case 3:
    case 4:
    case 5:
    case 6:
    case 7:
    case 8:
      break;

    case '\t':  // 9
    case 10:
      SkipWhitespace(peek);
      return true;

    case 11:
    case 12:
      break;

    case 13:
      SkipWhitespace(peek);
      return true;

    case 14:
    case 15:
    case 16:
    case 17:
    case 18:
    case 19:
    case 20:
    case 21:
    case 22:
    case 23:
    case 24:
    case 25:
    case 26:
    case 27:
    case 28:
    case 29:
    case 30:
    case 31:
      break;

    case ' ':  // 32
      SkipWhitespace(peek);
      return true;

    case '!':  // 33
      peek = Advance();
      if (peek == '=') return ScanSingle(kNE);
      return RecognizeSingle(peek, kNOT);

    case '"':  // 34
      return ScanString(peek, /* raw */ false);

    case '#':  // 35
      return ScanSingle(kHASH);

    case '$':  // 36
      return ScanIdentifier(peek);

    case '%':  // 37
      peek = Advance();
      if (peek == '=') return ScanSingle(kASSIGN_MOD);
      return RecognizeSingle(peek, kMOD);

    case '&':  // 38
      peek = Advance();
      if (peek == '=') return ScanSingle(kASSIGN_AND);
      if (peek == '&') return ScanSingle(kAND);
      return RecognizeSingle(peek, kBIT_AND);

    case '\'':  // 39
      return ScanString(peek, /* raw */ false);

    case '(':  // 40
      PushTokenBeginMarker(kLPAREN);
      return ScanSingle(kLPAREN);

    case ')':  // 41
      PopTokenBeginMarker(kLPAREN);
      return ScanSingle(kRPAREN);

    case '*':
      peek = Advance();
      if (peek == '=') return ScanSingle(kASSIGN_MUL);
      return RecognizeSingle(peek, kMUL);

    case '+':
      peek = Advance();
      if (peek == '=') return ScanSingle(kASSIGN_ADD);
      if (peek == '+') return ScanSingle(kINCREMENT);
      return RecognizeSingle(peek, kADD);

    case ',':  // 44
      return ScanSingle(kCOMMA);

    case '-':  // 45
      peek = Advance();
      if (peek == '=') return ScanSingle(kASSIGN_SUB);
      if (peek == '-') return ScanSingle(kDECREMENT);
      return RecognizeSingle(peek, kSUB);

    case '.':  // 46
      if (IsDecimalDigit(Peek())) return ScanNumber('.');
      peek = Advance();
      if (peek == '.') return ScanSingle(kCASCADE);
      return RecognizeSingle(peek, kPERIOD);

    case '/':  // 47
      peek = Advance();
      if (peek == '/') return SkipSinglelineComment(peek);
      if (peek == '*') return SkipMultilineComment(peek);
      if (peek == '=') return ScanSingle(kASSIGN_DIV);
      return RecognizeSingle(peek, kDIV);

    case '0':  // 48
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':  // 57
      return ScanNumber(peek);

    case ':':
      return ScanSingle(kCOLON);

    case ';':  // 59
      return ScanSingle(kSEMICOLON);

    case '<':  // 60
      peek = Advance();
      if (peek == '=') return ScanSingle(kLTE);
      if (peek == '<') {
        peek = Advance();
        if (peek == '=') return ScanSingle(kASSIGN_SHL);
        return RecognizeSingle(peek, kSHL);
      }
      PushTokenBeginMarker(kLT);
      return RecognizeSingle(peek, kLT);

    case '=':  // 61
      peek = Advance();
      if (peek == '=') return ScanSingle(kEQ);
      if (peek == '>') return ScanSingle(kARROW);
      return RecognizeSingle(peek, kASSIGN);

    case '>':  // 62
      peek = Advance();
      if (peek == '=') return ScanSingle(kGTE);
      if (peek == '>') {
        if (Peek() == '=') {
          Advance();
          return ScanSingle(kASSIGN_SHR);
        }
        PopTokenBeginMarker(kLT);
        if (!RecognizeSingle(peek, kGT_START)) return false;
        PopTokenBeginMarker(kLT);
        return ScanSingle(kGT);
      }
      PopTokenBeginMarker(kLT);
      return RecognizeSingle(peek, kGT);

    case '?':  // 63
      return ScanSingle(kCONDITIONAL);

    case '@':  // 64
      return ScanSingle(kAT);

    case 'A':  // 65
    case 'B':
    case 'C':
    case 'D':
    case 'E':
    case 'F':
    case 'G':
    case 'H':
    case 'I':
    case 'J':
    case 'K':
    case 'L':
    case 'M':
    case 'N':
    case 'O':
    case 'P':
    case 'Q':
    case 'R':
    case 'S':
    case 'T':
    case 'U':
    case 'V':
    case 'W':
    case 'X':
    case 'Y':
    case 'Z':  // 90
      return ScanIdentifier(peek);

    case '[':  // 91
      peek = Advance();
      if (peek == ']') {
        if (Peek() == '=') {
          Advance();
          return ScanSingle(kASSIGN_INDEX);
        }
        return ScanSingle(kINDEX);
      }
      return RecognizeSingle(peek, kLBRACK);

    case '\\':  // 92
      break;

    case ']':  // 93
      return ScanSingle(kRBRACK);

    case '^':  // 94
      peek = Advance();
      if (peek == '=') return ScanSingle(kASSIGN_XOR);
      return RecognizeSingle(peek, kBIT_XOR);

    case '_':  // 95
      return ScanIdentifier(peek);

    case 96:
      break;

    case 'a':  // 97
    case 'b':
    case 'c':
    case 'd':
    case 'e':
    case 'f':
    case 'g':
    case 'h':
    case 'i':
    case 'j':
    case 'k':
    case 'l':
    case 'm':
    case 'n':
    case 'o':
    case 'p':
    case 'q':
      return ScanIdentifier(peek);

    case 'r':
      // May be raw string.
      return ScanString(peek, /* raw */ true);

    case 's':
    case 't':
    case 'u':
    case 'v':
    case 'w':
    case 'x':
    case 'y':
    case 'z':  // 122
      return ScanIdentifier(peek);

    case '{':  // 123
      PushTokenBeginMarker(kLBRACE);
      return ScanSingle(kLBRACE);

    case '|':  // 124
      peek = Advance();
      if (peek == '|') return ScanSingle(kOR);
      if (peek == '=') return ScanSingle(kASSIGN_OR);
      return RecognizeSingle(peek, kBIT_OR);

    case '}':  // 125
      PopTokenBeginMarker(kLBRACE);
      return ScanSingle(kRBRACE);

    case '~':  // 126
      peek = Advance();
      if (peek == '/') {
        peek = Advance();
        if (peek == '=') return ScanSingle(kASSIGN_TRUNCDIV);
        return RecognizeSingle(peek, kTRUNCDIV);
      }
      return RecognizeSingle(peek, kBIT_NOT);

    case 127:
      break;
  }

  builder()->ReportError(start_location_ + index_,
                         "Unrecognized character: 0x%x",
                         peek);
  return false;
}

void Scanner::AddToken(Token token, int value) {
  TokenInfo info(value << 8 | token, start_location_ + begin_index_);
  tokens_.Add(info);
}

void Scanner::PushTokenBeginMarker(Token token) {
  TokenBeginMarker marker = { token, tokens_.length() };
  begin_marker_stack_.Add(marker);
}

void Scanner::PopTokenBeginMarker(Token token) {
  while (!begin_marker_stack_.is_empty()) {
    TokenBeginMarker marker = begin_marker_stack_.last();
    if (marker.token == token) {
      begin_marker_stack_.RemoveLast();
      int offset = tokens_.length() - marker.pos;
      TokenInfo info(offset << 8 | token, tokens_.Get(marker.pos).location());
      tokens_.Set(marker.pos, info);
      break;
    }
    if (token == kLT) break;
    if (marker.token != kLT && marker.token > token) break;
    begin_marker_stack_.RemoveLast();
  }
}

bool Scanner::ScanNumber(int peek) {
  int start = index_;
  Zone* trie_zone = builder()->zone();
  TerminalTrieNode* node = builder()->number_trie();
  if (!IsDecimalDigit(peek)) {
    node = node->Child(trie_zone, '0');
  } else {
    do {
      node = node->Child(trie_zone, peek);
      peek = Advance();
    } while (IsDecimalDigit(peek));
  }
  bool is_double = false;
  int base = 10;
  if ((index_ - start == 1) && (peek == 'x' || peek == 'X')) {
    base = 16;
    peek = Advance();
    while (IsHexDigit(peek)) {
      node = node->Child(trie_zone, peek);
      peek = Advance();
    }
  } else if (peek == '.' && IsDecimalDigit(Peek())) {
    is_double = true;
    node = node->Child(trie_zone, peek);
    peek = Advance();
    while (IsDecimalDigit(peek)) {
      node = node->Child(trie_zone, peek);
      peek = Advance();
    }
  }
  if (base == 10 && (peek == 'e' || peek == 'E')) {
    is_double = true;
    peek = Advance();
    if (peek == '-' || peek == '+') peek = Advance();
    while (IsDecimalDigit(peek)) {
      node = node->Child(trie_zone, peek);
      peek = Advance();
    }
  }
  int terminal = node->terminal_;
  if (terminal < 0) {
    // TODO(kasperl): Avoid the copy.
    const char* str = AllocateTerminal(start, index_);
    if (is_double) {
      double value = strtod(str, NULL);
      terminal = node->terminal_ = builder()->RegisterDouble(value);
    } else {
      int64 value = strtoll(str, NULL, base);
      if (errno == ERANGE) {
        builder()->ReportError(start_location_ + start,
                               "Unhandled large integer literal");
      }
      terminal = node->terminal_ = builder()->RegisterInteger(value);
    }
  }
  AddToken(is_double ? kDOUBLE : kINTEGER, terminal);
  return (peek != 0);
}

bool Scanner::ScanIdentifier(int peek, bool allow_dollar) {
  ASSERT(IsIdentifierStart(peek));
  int start = index_;
  Zone* trie_zone = builder()->zone();
  TerminalTrieNode* node = builder()->identifier_trie();
  if (allow_dollar) {
    do {
      node = node->Child(trie_zone, peek);
      peek = Advance();
    } while (IsIdentifierPart(peek));
  } else {
    do {
      node = node->Child(trie_zone, peek);
      peek = Advance();
    } while (IsIdentifierPart(peek) && peek != '$');
  }
  if (node->is_keyword_) {
    AddToken(static_cast<Token>(node->terminal_));
  } else {
    int terminal = node->terminal_;
    if (terminal < 0) {
      terminal = node->terminal_ = builder()->RegisterIdentifier(
          AllocateTerminal(start, index_));
    }
    AddToken(kIDENTIFIER, terminal);
  }
  return (peek != 0);
}

bool Scanner::ScanString(int peek, bool raw) {
  if (raw) {
    ASSERT(peek == 'r');
    if (!IsStringStart(Peek())) return ScanIdentifier(peek);
    peek = Advance();
  }
  // TODO(ajohnsen): Clean up, and parse strings.
  ASSERT(IsStringStart(peek));
  int start = index_ + 1;
  int quote = peek;
  bool multiline = false;
  if (Peek(1) == quote && Peek(2) == quote) {
    // Multiline string.
    Advance();
    Advance();
    multiline = true;
    start += 2;
    int offset = 1;
    while (IsWhitespace(Peek(offset))) {
      if (IsNewline(Peek(offset))) {
        start += offset;
        break;
      }
      offset++;
    }
  }
  bool interpolation = false;
  // If the list is non-raw and escape sequences is hit, parsed_chars is
  // used to build the string.
  string_literal_buffer_.Clear();
  while (peek != 0) {
    peek = Advance();
    if (peek == quote) {
      int end = index_;
      if (multiline) {
        if (Peek(1) == quote && Peek(2) == quote) {
          Advance();
          Advance();
        } else {
          continue;
        }
      }
      Token token = interpolation ? kSTRING_INTERPOLATION_END : kSTRING;
      NewString(token, start, end);
      return (Advance() != 0);
    } else if (!raw) {
      if (peek == '\\') {
        if (string_literal_buffer_.is_empty()) {
          // Copy up to index_.
          for (int i = start; i < index_; i++) {
            string_literal_buffer_.Add(input_[i]);
          }
        }
        peek = Advance();
        switch (peek) {
          case 'b': string_literal_buffer_.Add('\b'); break;
          case 'f': string_literal_buffer_.Add('\f'); break;
          case 'n': string_literal_buffer_.Add('\n'); break;
          case 'r': string_literal_buffer_.Add('\r'); break;
          case 't': string_literal_buffer_.Add('\t'); break;
          case 'v': string_literal_buffer_.Add('\v'); break;
          // TODO(ajohnsen): Handle \x, and \u escape sequences.

          default:
            string_literal_buffer_.Add(peek);
        }
      } else if (peek == '$') {
        interpolation = true;
        int end = index_;
        peek = Advance();
        if (IsIdentifierStart(peek)) {
          NewString(kSTRING_INTERPOLATION, start, end);
          if (!ScanIdentifier(peek, false)) break;
          // Clear state and continue.
          string_literal_buffer_.Clear();
          start = index_;
          index_--;
          continue;
        }
        if (peek == '{') {
          Advance();
          NewString(kSTRING_INTERPOLATION, start, end);
          // Simulate {..} on the marker stack.
          TokenBeginMarker marker = {kLBRACE, 0};
          begin_marker_stack_.Add(marker);
          int indent = begin_marker_stack_.length();
          while (true) {
            if (!ScanUntil('}')) {
              builder()->ReportError(
                  start_location_ + index_, "Unterminated string literal");
              return false;
            }
            if (begin_marker_stack_.length() < indent) {
              builder()->ReportError(
                  start_location_ + index_, "Bad string interpolation");
              return false;
            }
            while (begin_marker_stack_.last().token != kLBRACE) {
              begin_marker_stack_.RemoveLast();
            }
            if (begin_marker_stack_.length() == indent) break;
            ScanToken();
          }
          begin_marker_stack_.RemoveLast();
          // Clear state and continue.
          string_literal_buffer_.Clear();
          start = index_ + 1;
          continue;
        }

        builder()->ReportError(
            start_location_ + index_, "Bad string interpolation start");
      } else if (!string_literal_buffer_.is_empty()) {
        string_literal_buffer_.Add(peek);
      }
    }
  }
  builder()->ReportError(
      start_location_ + index_, "Unterminated string literal");
  return false;
}

void Scanner::NewString(Token token, int start, int end) {
  const char* value;
  if (string_literal_buffer_.is_empty()) {
    value = AllocateTerminal(start, end);
  } else {
    string_literal_buffer_.Add('\0');
    value = string_literal_buffer_.ToList(builder()->zone()).data();
  }
  AddToken(token, builder()->RegisterString(value));
}

bool Scanner::ScanSingle(Token token) {
  AddToken(token);
  return (Advance() != 0);
}

bool Scanner::RecognizeSingle(int peek, Token token) {
  AddToken(token);
  return (peek != 0);
}

void Scanner::SkipWhitespace(int peek) {
  ASSERT(IsWhitespace(peek));
  do {
    peek = Advance();
  } while (IsWhitespace(peek));
}

bool Scanner::SkipSinglelineComment(int peek) {
  ASSERT(peek == '/');
  do {
    peek = Advance();
    if (peek == 0) return false;
  } while (!IsNewline(peek));
  return true;
}

bool Scanner::SkipMultilineComment(int peek) {
  int start = index_;
  ASSERT(peek == '*');
  peek = Advance();
  int nesting = 1;
  do {
    if (peek == '*') {
      peek = Advance();
      if (peek == '/') {
        peek = Advance();
        nesting--;
        if (nesting == 0) return true;
      }
    } else if (peek == '/') {
      peek = Advance();
      if (peek == '*') {
        // Nested comment.
        nesting++;
        peek = Advance();
      }
    } else {
      // Just skip to the next one.
      peek = Advance();
    }
  } while (peek != 0);
  builder()->ReportError(
      start_location_ + start, "Unterminated multiline comment");
  return false;
}

const char* Scanner::AllocateTerminal(int start, int end) {
  int length = end - start;
  char* buffer = static_cast<char*>(builder()->zone()->Allocate(length + 1));
  memcpy(buffer, input_ + start, length);
  buffer[length] = 0;
  return buffer;
}

}  // namespace fletch
