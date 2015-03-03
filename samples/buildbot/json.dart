// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';

int _min(int m, int n) => (m < n) ? m : n;

dynamic getJson(String host, String resource) {
  var socket = new Socket.connect(host, 80);
  HttpConnection connection = new HttpConnection(socket);
  HttpRequest request = new HttpRequest(resource);
  request.headers["Host"] = host;
  HttpResponse response = connection.send(request);
  return new JsonParser(new String.fromCharCodes(response.body)).parse();
}

class JsonParser {
  int _index = 0;
  String _json;
  String _whitespaceUnits = ' \t\n';
  String _delimiterUnits = ' \t\n,[]{}';

  JsonParser(this._json);

  dynamic parse() {
    _whitespace();
    var result = _parseValue();
    _whitespace();
    if (_hasCurrent) {
      throw "Parse failed to consume: ${_json.substring(_index)}";
    }
    return result;
  }

  int get _currentUnit => _json.codeUnitAt(_index);
  String get _current => _json[_index];
  bool get _hasCurrent => _index < _json.length;

  bool _containsCurrent(String units) {
    int length = units.length;
    int unit = _currentUnit;
    for (int i = 0; i < length; ++i) {
      if (unit == units.codeUnitAt(i)) return true;
    }
    return false;
  }

  void _whitespace() {
    while (_hasCurrent && _containsCurrent(_whitespaceUnits)) ++_index;
  }

  void _parseToken(String token) {
    if (!_tryParseToken(token)) {
      throw "Expected $token at index $_index, found $_current";
    }
  }

  bool _tryParseToken(String token) {
    int length = token.length;
    int start = _index;
    int end = start + length;
    if (end > _json.length) return false;
    for (int i = 0; i < length; ++i) {
      if (token.codeUnitAt(i) != _json.codeUnitAt(start + i)) {
        return false;
      }
    }
    _index += length;
    return true;
  }

  bool get _isDelimiter => _containsCurrent(_delimiterUnits);

  String _readToken() {
    int start = _index;
    while (_hasCurrent && !_isDelimiter) ++_index;
    return _json.substring(start, _index);
  }

  dynamic _parseValue() {
    _whitespace();
    if (_tryParseToken('{')) return _parseMap();
    if (_tryParseToken('[')) return _parseList();
    if (_tryParseToken('"')) return _parseString();
    if (_tryParseToken('true')) return true;
    if (_tryParseToken('false')) return false;
    if (_tryParseToken('null')) return null;

    int tryIndex = _index;
    String token = _readToken();
    bool error = false;
    // TODO(zerny) floating point numbers.
    int tryInt = int.parse(token, onError: (_) { error = true; return 0; });
    if (!error) return tryInt;

    String context = _json.substring(tryIndex, _min(tryIndex + 10, _json.length));
    throw "Parse failed at index: $_index (context: '$context...')";
  }

  Map _parseMap() {
    Map map = new Map();
    _whitespace();
    while (!_tryParseToken('}')) {
      var key = _parseValue();
      _whitespace();
      _parseToken(':');
      var value = _parseValue();
      map[key] = value;
      _whitespace();
      _tryParseToken(',');
      _whitespace();
    }
    return map;
  }

  List _parseList() {
    List list = new List();
    _whitespace();
    while (!_tryParseToken(']')) {
      list.add(_parseValue());
      _whitespace();
      _tryParseToken(',');
      _whitespace();
    }
    return list;
  }

  String _parseString() {
    int start = _index;
    while (_hasCurrent && _current != '"') ++_index;
    return _json.substring(start, _index++);
  }
}
