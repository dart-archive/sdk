// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library http;

import 'dart:collection';
import 'dart:typed_data';

import 'package:charcode/ascii.dart';
import 'package:socket/socket.dart';

ByteBuffer stringToByteBuffer(String str) {
  Uint8List list = new Uint8List(str.length);
  for (int i = 0; i < list.length; i++) {
    list[i] = str.codeUnitAt(i);
  }
  return list.buffer;
}

class HttpConnection {
  final Socket socket;
  HttpConnection(this.socket);

  HttpResponse send(HttpRequest request, {ByteBuffer body}) {
    StringBuffer header = new StringBuffer();
    header.write(request.method);
    header.write(" ");
    header.write(request.path);
    header.write(" HTTP/1.1\r\n");
    header.write(request.headers);
    header.write("\r\n");
    socket.write(stringToByteBuffer(header.toString()));

    // TODO(ajohnsen): Send body.

    var parser = new _HttpParser(socket);
    return parser.parse();
  }
}

class HttpRequest {
  final String method;
  final String path;
  final HttpHeaders headers = new HttpHeaders();

  HttpRequest(this.path) : method = 'GET';
  HttpRequest.get(this.path) : method = 'GET';
  HttpRequest.post(this.path) : method = 'POST';
}

class HttpResponse {
  final int statusCode;
  final String reasonPhrase;
  final HttpHeaders headers;
  final Uint8List body;

  HttpResponse._(this.statusCode,
                 this.reasonPhrase,
                 this.headers,
                 this.body);
}

class HttpHeaders {
  // TODO(ajohnsen): Make keys lower case strings.
  final Map<String, List<String>> _values = new HashMap<String, List<String>>();

  String operator[](String key) {
    List list = _values[key];
    if (list == null) return null;
    return list.last;
  }

  void operator[]=(String key, String value) {
    _values[key] = [value];
  }

  void add(String key, String value) {
    _values.putIfAbsent(key, () => []).add(value);
  }

  List<String> values(String key) {
    List list = _values[key];
    if (list == null) return const [];
    return list;
  }

  String toString() {
    StringBuffer buffer = new StringBuffer();
    _values.forEach((String key, List<String> values) {
      for (String value in values) {
        buffer.write(key);
        buffer.write(": ");
        buffer.write(value);
        buffer.write("\r\n");
      }
    });
    return buffer.toString();
  }
}

class _HttpParser {
  final Socket socket;

  var _buffer = const [];
  var _offset = 0;

  _HttpParser(this.socket);

  HttpResponse parse() {
    HttpHeaders headers = new HttpHeaders();

    // Parse the first line:
    //  'HTTP/1.1 <3*digit> <*Text>\r\n'
    _expect($H);
    _expect($T);
    _expect($T);
    _expect($P);
    _expect($slash);
    _expect($1);
    _expect($dot);
    _expect($1);

    _expect($space);

    int statusCode = 0;
    for (int i = 0; i < 3; i++) {
      int char = _peek();
      if (!_isDigit(char)) throw "Expected status code";
      statusCode *= 10;
      statusCode += char - $0;
      _consume();
    }

    _expect($space);

    List reasonPhrase = [];
    while (true) {
      int char = _peek();
      if (char == $cr) break;
      reasonPhrase.add(char);
      _consume();
    }

    _expect($cr);
    _expect($lf);

    // We now parse all the headers. They are seperated by '\r\n'. An extra
    // '\r\n' marks the end of headers.
    while (_peek() != $cr) {
      String fieldName = _parseToken();
      _expect($colon);

      while (_peek() == $space) _consume();

      List data = [];
      while (true) {
        int char = _peek();
        if (char == $cr) break;
        data.add(char);
        _consume();
      }

      String fieldValue = new String.fromCharCodes(data);

      headers.add(fieldName, fieldValue);

      _expect($cr);
      _expect($lf);
    }

    _expect($cr);
    _expect($lf);

    // We are now done with all of the headers; the body begins. There are 3
    // formats for the body
    //  - Fixed length (content-length is >= 0)
    //  - Unknown length - chunked encoding
    //  - Unkonwn length - to socket read is closed (content-length is -1)
    // TODO(ajohnsen): Handle chunked and streaming.
    String contentLengthValue = headers["Content-Length"];
    Uint8List body;
    if (contentLengthValue != null) {
      int contentLength = int.parse(contentLengthValue);
      if (contentLength >= 0) {
        int bufferRemaining = _buffer.length - _offset;
        int missingLength = contentLength - bufferRemaining;
        Uint8List remaining = new Uint8List.view(socket.read(missingLength));

        body = new Uint8List(contentLength);
        body.setRange(0, bufferRemaining, _buffer, _offset);
        body.setRange(bufferRemaining, contentLength, remaining);
      }
    } else if (headers["Transfer-Encoding"] == "chunked") {
      int contentLength = 0;
      List chunks = [];

      while (true) {
        int count = 0;
        int char = _peek();
        while (char != $cr && char != $semicolon) {
          _consume();
          ++count;
          char = _peek();
        }
        Uint8List chars = new Uint8List.view(_buffer, _offset - count, count);
        int chunkLength = int.parse(new String.fromCharCodes(chars), radix: 16);

        // TODO(zerny): support optional extensions.
        if (char == $semicolon) {
          while (_peek() != $cr) _consume();
        }

        _expect($cr);
        _expect($lf);

        // A zero-size chunk denotes the last chunk.
        if (chunkLength == 0) break;

        int bufferRemaining = _buffer.length - _offset;
        int chunkRemaining = chunkLength;
        while (chunkRemaining > bufferRemaining) {
          chunks.add(new Uint8List.view(_buffer, _offset, bufferRemaining));
          chunkRemaining -= bufferRemaining;
          _buffer = new Uint8List.view(socket.readNext());
          _offset = 0;
          bufferRemaining = _buffer.length;
        }
        chunks.add(new Uint8List.view(_buffer, _offset, chunkRemaining));
        _offset += chunkRemaining;

        contentLength += chunkLength;

        _expect($cr);
        _expect($lf);
      }

      // TODO(zerny): read optional trailer
      while (_peek() != $cr) _consume();
      _expect($cr);
      _expect($lf);

      body = new Uint8List(contentLength);
      int offset = 0;
      int chunkCount = chunks.length;
      for (int i = 0; i < chunkCount; ++i) {
        Uint8List chunk = chunks[i];
        int chunkLength = chunk.length;
        body.setRange(offset, offset + chunkLength, chunk);
        offset += chunkLength;
      }
    }

    if (body == null) throw "Failed to read body";
    return new HttpResponse._(statusCode,
                              new String.fromCharCodes(reasonPhrase),
                              headers,
                              body);
  }

  String _parseToken() {
    var list = [];
    while (true) {
      var char = _peek();
      if (!_isTokenChar(char)) break;
      list.add(char);
      _consume();
    }
    if (list.isEmpty) throw "Bad token";
    return new String.fromCharCodes(list);
  }


  void _expect(int char) {
    if (_peek() != char) throw "Expected $char but got ${_peek()}";
    _consume();
  }

  int _peek() {
    if (_offset == _buffer.length) {
      _buffer = new Uint8List.view(socket.readNext());
      _offset = 0;
    }
    return _buffer[_offset];
  }

  void _consume() {
    _offset++;
  }

  static bool _isTokenChar(int char) => _isChar(char) && !_isSeparator(char);

  static bool _isChar(int char) => char >= 32 && char <= 126;
  static bool _isDigit(int char) => char >= $0 && char <= $9;

  static bool _isSeparator(int char) {
    // TODO(ajohnsen): "(" | ")" | "<" | ">" | "@" | "," | ";" | ":" |
    // "\" | <"> | "/" | "[" | "]" | "?" | "=" | "{" | "}" | SP | HT
    return char == $space || char == $slash || char == $colon;
  }
}
