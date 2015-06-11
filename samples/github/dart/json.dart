// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert' show UTF8;

import 'package:http/http.dart';

import 'github_services.dart';

int _min(int m, int n) => (m < n) ? m : n;

dynamic getJson(Connection service, String resource) {
  HttpConnection connection = new HttpConnection(service.connect());
  HttpRequest request = new HttpRequest('${service.host}/$resource');
  request.headers["Host"] = service.host;
  request.headers["User-Agent"] = 'fletch';
  HttpResponse response = connection.send(request);
  if (response.statusCode != 200) {
    throw 'Failed request: $resource on port $port';
  }
  return new JsonParser(UTF8.decode(response.body)).parse();
}

class JsonParser {
  int _offset = 0;
  String _json;

  JsonParser(this._json);

  dynamic parse() {
    _whitespace();
    var result = _parseValue();
    _whitespace();
    if (_hasCurrent) {
      throw "Parse failed to consume: ${_json.substring(_offset)}";
    }
    return result;
  }

  bool get _hasCurrent => _offset < _json.length;
  int get _current => _json.codeUnitAt(_offset);
  String get _currentChar => _json[_offset];
  void _consume() { ++_offset; }

  void _whitespace() {
    while (_hasCurrent && _isWhitespace(_current)) _consume();
  }

  bool _optional(int char) {
    if (_current == char) {
      _consume();
      return true;
    }
    return false;
  }

  void _expect(int char) {
    if (!_optional(char)) {
      String string = new String.fromCharCodes([char]);
      throw "Expected $string at index $_offset, found $_currentChar";
    }
  }

  bool _tryParseToken(String token) {
    int length = token.length;
    int start = _offset;
    int end = start + length;
    if (end > _json.length) return false;
    for (int i = 0; i < length; ++i) {
      if (token.codeUnitAt(i) != _json.codeUnitAt(start + i)) {
        return false;
      }
    }
    _offset += length;
    return true;
  }

  String _readToken() {
    int start = _offset;
    while (_hasCurrent && !_isSeparator(_current)) _consume();
    return _json.substring(start, _offset);
  }

  dynamic _parseValue() {
    _whitespace();
    if (_optional(_CHAR_BRACE_OPEN)) return _parseMap();
    if (_optional(_CHAR_SQUARE_OPEN)) return _parseList();
    if (_optional(_CHAR_DOUBLE_QUOTE)) return _parseString();
    if (_tryParseToken(_TOKEN_TRUE)) return true;
    if (_tryParseToken(_TOKEN_FALSE)) return false;
    if (_tryParseToken(_TOKEN_NULL)) return null;

    int start = _offset;
    String token = _readToken();
    bool error = false;
    // TODO(zerny) floating point numbers.
    int tryInt = int.parse(token, onError: (_) { error = true; return 0; });
    if (!error) return tryInt;

    String context = _json.substring(start, _min(start + 10, _json.length));
    throw "Parse failed at index: $_offset (context: '$context...')";
  }

  Map _parseMap() {
    Map map = new Map();
    _whitespace();
    if (_current != _CHAR_BRACE_CLOSE) {
      do {
        var key = _parseValue();
        _whitespace();
        _expect(_CHAR_COLON);
        var value = _parseValue();
        map[key] = value;
        _whitespace();
      } while (_optional(_CHAR_COMMA));
    }
    _expect(_CHAR_BRACE_CLOSE);
    return map;
  }

  List _parseList() {
    List list = new List();
    _whitespace();
    if (_current != _CHAR_SQUARE_CLOSE) {
      do {
        list.add(_parseValue());
        _whitespace();
      } while (_optional(_CHAR_COMMA));
    }
    _expect(_CHAR_SQUARE_CLOSE);
    return list;
  }

  String _parseString() {
    int start = _offset;
    while (_hasCurrent && _current != _CHAR_DOUBLE_QUOTE) {
      if (_current == _CHAR_BACKSLASH) _consume();
      _consume();
    }
    _expect(_CHAR_DOUBLE_QUOTE);
    return _json.substring(start, _offset - 1);
  }

  static bool _isWhitespace(int char) =>
    char == _CHAR_TAB ||
    char == _CHAR_LINE_FEED ||
    char == _CHAR_SPACE;

  static bool _isSeparator(int char) =>
    _isWhitespace(char) ||
    char == _CHAR_PAREN_OPEN ||
    char == _CHAR_PAREN_CLOSE ||
    char == _CHAR_COMMA ||
    char == _CHAR_COLON ||
    char == _CHAR_SQUARE_OPEN ||
    char == _CHAR_SQUARE_CLOSE ||
    char == _CHAR_BRACE_OPEN ||
    char == _CHAR_BRACE_CLOSE;

  static const String _TOKEN_TRUE = 'true';
  static const String _TOKEN_FALSE = 'false';
  static const String _TOKEN_NULL = 'null';

  static const int _CHAR_TAB = 9;
  static const int _CHAR_LINE_FEED = 10;
  static const int _CHAR_SPACE = 32;
  static const int _CHAR_DOUBLE_QUOTE = 34;
  static const int _CHAR_PAREN_OPEN = 40;
  static const int _CHAR_PAREN_CLOSE = 41;
  static const int _CHAR_COMMA = 44;
  static const int _CHAR_COLON = 58;
  static const int _CHAR_SQUARE_OPEN = 91;
  static const int _CHAR_BACKSLASH = 92;
  static const int _CHAR_SQUARE_CLOSE = 93;
  static const int _CHAR_BRACE_OPEN = 123;
  static const int _CHAR_BRACE_CLOSE = 125;
}
