// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// HTTP client implementation.
library http;

import 'dart:collection';
import 'dart:typed_data';

import 'package:charcode/ascii.dart';
import 'package:socket/socket.dart';

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  String toString() => "HttpException: $message";
}

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

/// HTTP status codes.
abstract class HttpStatus {
  static const int CONTINUE = 100;
  static const int SWITCHING_PROTOCOLS = 101;
  static const int OK = 200;
  static const int CREATED = 201;
  static const int ACCEPTED = 202;
  static const int NON_AUTHORITATIVE_INFORMATION = 203;
  static const int NO_CONTENT = 204;
  static const int RESET_CONTENT = 205;
  static const int PARTIAL_CONTENT = 206;
  static const int MULTIPLE_CHOICES = 300;
  static const int MOVED_PERMANENTLY = 301;
  static const int FOUND = 302;
  static const int MOVED_TEMPORARILY = 302; // Common alias for FOUND.
  static const int SEE_OTHER = 303;
  static const int NOT_MODIFIED = 304;
  static const int USE_PROXY = 305;
  static const int TEMPORARY_REDIRECT = 307;
  static const int BAD_REQUEST = 400;
  static const int UNAUTHORIZED = 401;
  static const int PAYMENT_REQUIRED = 402;
  static const int FORBIDDEN = 403;
  static const int NOT_FOUND = 404;
  static const int METHOD_NOT_ALLOWED = 405;
  static const int NOT_ACCEPTABLE = 406;
  static const int PROXY_AUTHENTICATION_REQUIRED = 407;
  static const int REQUEST_TIMEOUT = 408;
  static const int CONFLICT = 409;
  static const int GONE = 410;
  static const int LENGTH_REQUIRED = 411;
  static const int PRECONDITION_FAILED = 412;
  static const int REQUEST_ENTITY_TOO_LARGE = 413;
  static const int REQUEST_URI_TOO_LONG = 414;
  static const int UNSUPPORTED_MEDIA_TYPE = 415;
  static const int REQUESTED_RANGE_NOT_SATISFIABLE = 416;
  static const int EXPECTATION_FAILED = 417;
  static const int INTERNAL_SERVER_ERROR = 500;
  static const int NOT_IMPLEMENTED = 501;
  static const int BAD_GATEWAY = 502;
  static const int SERVICE_UNAVAILABLE = 503;
  static const int GATEWAY_TIMEOUT = 504;
  static const int HTTP_VERSION_NOT_SUPPORTED = 505;
  // Client generated status code.
  static const int NETWORK_CONNECT_TIMEOUT_ERROR = 599;
}

abstract class HttpHeaderFields {
  static const ACCEPT = "accept";
  static const ACCEPT_CHARSET = "accept-charset";
  static const ACCEPT_ENCODING = "accept-encoding";
  static const ACCEPT_LANGUAGE = "accept-language";
  static const ACCEPT_RANGES = "accept-ranges";
  static const AGE = "age";
  static const ALLOW = "allow";
  static const AUTHORIZATION = "authorization";
  static const CACHE_CONTROL = "cache-control";
  static const CONNECTION = "connection";
  static const CONTENT_ENCODING = "content-encoding";
  static const CONTENT_LANGUAGE = "content-language";
  static const CONTENT_LENGTH = "content-length";
  static const CONTENT_LOCATION = "content-location";
  static const CONTENT_MD5 = "content-md5";
  static const CONTENT_RANGE = "content-range";
  static const CONTENT_TYPE = "content-type";
  static const DATE = "date";
  static const ETAG = "etag";
  static const EXPECT = "expect";
  static const EXPIRES = "expires";
  static const FROM = "from";
  static const HOST = "host";
  static const IF_MATCH = "if-match";
  static const IF_MODIFIED_SINCE = "if-modified-since";
  static const IF_NONE_MATCH = "if-none-match";
  static const IF_RANGE = "if-range";
  static const IF_UNMODIFIED_SINCE = "if-unmodified-since";
  static const LAST_MODIFIED = "last-modified";
  static const LOCATION = "location";
  static const MAX_FORWARDS = "max-forwards";
  static const PRAGMA = "pragma";
  static const PROXY_AUTHENTICATE = "proxy-authenticate";
  static const PROXY_AUTHORIZATION = "proxy-authorization";
  static const RANGE = "range";
  static const REFERER = "referer";
  static const RETRY_AFTER = "retry-after";
  static const SERVER = "server";
  static const TE = "te";
  static const TRAILER = "trailer";
  static const TRANSFER_ENCODING = "transfer-encoding";
  static const UPGRADE = "upgrade";
  static const USER_AGENT = "user-agent";
  static const VARY = "vary";
  static const VIA = "via";
  static const WARNING = "warning";
  static const WWW_AUTHENTICATE = "www-authenticate";
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
  final Map<String, List<String>> _values = new HashMap<String, List<String>>();

  // TODO(karlklose): join the values (see RFC 2616).
  String operator[](String key) =>_values[key.toLowerCase()]?.last;

  void operator[]=(String key, String value) {
    _values[key.toLowerCase()] = [value];
  }

  void add(String key, String value) {
    // If the key is already present, verify that it allows multiple values.
    _values.putIfAbsent(key.toLowerCase(), () => []).add(value);
  }

  List<String> values(String key) {
    List list = _values[key.toLowerCase()];
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

  // These getters avoid converting the key to lowercase.
  String get contentType => _values[HttpHeaderFields.CONTENT_TYPE]?.last;
  String get contentLength => _values[HttpHeaderFields.CONTENT_LENGTH]?.last;
  String get transferEncoding {
    return _values[HttpHeaderFields.TRANSFER_ENCODING]?.last;
  }
}

class _HttpParser {
  final Socket socket;

  Uint8List _buffer = new Uint8List(0);
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
      if (!_isDigit(char)) _fail("Expected status code");
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
    String contentLengthValue = headers.contentLength;
    Uint8List body;
    if (contentLengthValue != null) {
      int contentLength = int.parse(contentLengthValue);
      if (contentLength >= 0) {
        int bufferRemaining = _buffer.length - _offset;
        int missingLength = contentLength - bufferRemaining;
        Uint8List remaining = new Uint8List.view(_read(missingLength));

        body = new Uint8List(contentLength);
        body.setRange(0, bufferRemaining, _buffer, _offset);
        body.setRange(bufferRemaining, contentLength, remaining);
      }
    } else if (headers.transferEncoding == "chunked") {
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
        Uint8List chars = new Uint8List.view(_buffer.buffer, _offset - count,
            count);
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
          chunks.add(new Uint8List.view(_buffer.buffer, _offset,
                  bufferRemaining));
          chunkRemaining -= bufferRemaining;
          _buffer = new Uint8List.view(_read());
          _offset = 0;
          bufferRemaining = _buffer.length;
        }
        chunks.add(new Uint8List.view(_buffer.buffer, _offset, chunkRemaining));
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

    if (body == null) {
      _fail("Failed to read body");
    }
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
    if (list.isEmpty) {
      _fail("Bad token");
    }
    return new String.fromCharCodes(list);
  }


  void _expect(int char) {
    if (_peek() != char) {
      _fail("Expected $char but got ${_peek()}");
    }
    _consume();
  }

  ByteBuffer _read([int length = -1]) {
    ByteBuffer buffer = length > 0 ? socket.read(length) : socket.readNext();
    if (buffer == null) {
      _fail("Connection reset by server");
    }
    return buffer;
  }

  int _peek() {
    if (_offset == _buffer.length) {
      _buffer = new Uint8List.view(_read());
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

  _fail(String message) => throw new HttpException(message);
}
