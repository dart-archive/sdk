// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
class Uri {
  final String scheme = "";

  String get authority {
    throw new UnimplementedError("Uri.authority");
  }

  String get userInfo {
    throw new UnimplementedError("Uri.userInfo");
  }

  String get host {
    throw new UnimplementedError("Uri.host");
  }

  int get port {
    throw new UnimplementedError("Uri.port");
  }

  String get path {
    throw new UnimplementedError("Uri.path");
  }

  String get query {
    throw new UnimplementedError("Uri.query");
  }

  String get fragment {
    throw new UnimplementedError("Uri.fragment");
  }

  static Uri parse(String uri) {
    throw new UnimplementedError("Uri.parse");
  }

  factory Uri({String scheme : "",
               String userInfo : "",
               String host,
               int port,
               String path,
               Iterable<String> pathSegments,
               String query,
               Map<String, String> queryParameters,
               String fragment}) {
    throw new UnimplementedError("Uri");
  }

  factory Uri.http(String authority,
                   String unencodedPath,
                   [Map<String, String> queryParameters]) {
    throw new UnimplementedError("Uri.http");
  }

  factory Uri.https(String authority,
                    String unencodedPath,
                    [Map<String, String> queryParameters]) {
    throw new UnimplementedError("Uri.https");
  }

  factory Uri.file(String path, {bool windows}) {
    throw new UnimplementedError("Uri.file");
  }

  static Uri get base {
    throw new UnimplementedError("Uri.base");
  }

  Uri replace({String scheme,
               String userInfo,
               String host,
               int port,
               String path,
               Iterable<String> pathSegments,
               String query,
               Map<String, String> queryParameters,
               String fragment}) {
    throw new UnimplementedError("Uri.replace");
  }

  List<String> get pathSegments {
    throw new UnimplementedError("Uri.pathSegments");
  }

  Map<String, String> get queryParameters {
    throw new UnimplementedError("Uri.queryParameters");
  }

  bool get isAbsolute {
    throw new UnimplementedError("Uri.isAbsolute");
  }

  Uri resolve(String reference) {
    throw new UnimplementedError("Uri.resolve");
  }

  Uri resolveUri(Uri reference) {
    throw new UnimplementedError("Uri.resolveUri");
  }

  bool get hasAuthority {
    throw new UnimplementedError("Uri.hasAuthority");
  }

  bool get hasPort {
    throw new UnimplementedError("Uri.hasPort");
  }

  bool get hasQuery {
    throw new UnimplementedError("Uri.hasQuery");
  }

  bool get hasFragment {
    throw new UnimplementedError("Uri.hasFragment");
  }

  String get origin {
    throw new UnimplementedError("Uri.origin");
  }

  String toFilePath({bool windows}) {
    throw new UnimplementedError("Uri.toFilePath");
  }

  String toString() {
    throw new UnimplementedError("Uri.toString");
  }

  bool operator==(other) {
    throw new UnimplementedError("Uri.==");
  }

  int get hashCode {
    throw new UnimplementedError("Uri.hashCode");
  }

  static String encodeComponent(String component) {
    throw new UnimplementedError("Uri.encodeComponent");
  }

  static String encodeQueryComponent(String component,
                                     {Encoding encoding: UTF8}) {
    throw new UnimplementedError("Uri.encodeQueryComponent");
  }

  static String decodeComponent(String encodedComponent) {
    throw new UnimplementedError("Uri.decodeComponent");
  }

  static String decodeQueryComponent(String encodedComponent,
                                     {Encoding encoding: UTF8}) {
    throw new UnimplementedError("Uri.decodeQueryComponent");
  }

  static String encodeFull(String uri) {
    throw new UnimplementedError("Uri.encodeFull");
  }

  static String decodeFull(String uri) {
    throw new UnimplementedError("Uri.decodeFull");
  }

  static Map<String, String> splitQueryString(String query,
                                              {Encoding encoding: UTF8}) {
    throw new UnimplementedError("Uri.splitQueryString");
  }

  static List<int> parseIPv4Address(String host) {
    throw new UnimplementedError("Uri.parseIPv4Address");
  }

  static List<int> parseIPv6Address(String host, [int start = 0, int end]) {
    throw new UnimplementedError("Uri.parseIPv6Address");
  }
}
