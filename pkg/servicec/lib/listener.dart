// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.listener;

import 'package:compiler/src/scanner/scannerlib.dart' show
    ErrorToken,
    Token;

import 'errors.dart' show
    CompilerError;

import 'keyword.dart' show
    Keyword;

/// Identity listener: methods just propagate the argument.
abstract class Listener {
  Iterable<CompilerError> get errors;

  Token beginCompilationUnit(Token tokens) {
    return tokens;
  }

  Token endCompilationUnit(Token tokens, int count) {
    return tokens;
  }

  Token beginTopLevel(Token tokens) {
    return tokens;
  }

  Token endTopLevel(Token tokens) {
    return tokens;
  }

  Token beginService(Token tokens) {
    return tokens;
  }

  Token endService(Token tokens, int count) {
    return tokens;
  }

  Token beginStruct(Token tokens) {
    return tokens;
  }

  Token endStruct(Token tokens, int count) {
    return tokens;
  }

  Token beginIdentifier(Token tokens) {
    return tokens;
  }

  Token endIdentifier(Token tokens) {
    return tokens;
  }

  Token beginFunction(Token tokens) {
    return tokens;
  }

  Token endFunction(Token tokens, int count) {
    return tokens;
  }

  Token beginMember(Token tokens) {
    return tokens;
  }

  Token endMember(Token tokens) {
    return tokens;
  }

  Token beginType(Token tokens) {
    return tokens;
  }

  Token endType(Token tokens) {
    return tokens;
  }

  Token handleSimpleType(Token tokens) {
    return tokens;
  }

  Token handlePointerType(Token tokens) {
    return tokens;
  }

  Token handleListType(Token tokens) {
    return tokens;
  }

  Token beginFormal(Token tokens) {
    return tokens;
  }

  Token endFormal(Token tokens) {
    return tokens;
  }

  Token expectedTopLevel(Token tokens);

  Token expectedIdentifier(Token tokens);

  Token expectedType(Token tokens);

  Token expected(String string, Token tokens);
}

enum LogLevel { DEBUG, INFO }

/// Used for debugging other listeners.
class DebugListener implements Listener {
  Iterable<CompilerError> get errors => debugSubject.errors;

  Listener debugSubject;
  LogLevel logLevel;
  int scope;

  DebugListener(this.debugSubject, [this.logLevel = LogLevel.DEBUG])
    : scope = 0;

  void beginScope() { ++scope; }
  void endScope() { --scope; }

  void log(String string) {
    print("${"  " * scope}$string");
  }

  void logBeginScope(String nodeName) {
    String prefix = logLevel == LogLevel.INFO ? "begin " : "";
    log("$prefix$nodeName");
    beginScope();
  }

  void logEndScope(String nodeName, [String summary = ""]) {
    if (logLevel == LogLevel.DEBUG) {
      if (summary != "") log("$summary");
      endScope();
    } else {
      endScope();
      log("end $nodeName; $summary");
    }
  }

  Token beginCompilationUnit(Token tokens) {
    logBeginScope("unit");
    return debugSubject.beginCompilationUnit(tokens);
  }

  Token endCompilationUnit(Token tokens, int count) {
    logEndScope("unit", "top-level declarations count = $count");
    return debugSubject.endCompilationUnit(tokens, count);
  }

  Token beginTopLevel(Token tokens) {
    logBeginScope("top-level declaration");
    return debugSubject.beginTopLevel(tokens);
  }

  Token endTopLevel(Token tokens) {
    logEndScope("top-level declaration");
    return debugSubject.endTopLevel(tokens);
  }

  Token beginService(Token tokens) {
    logBeginScope("service");
    return debugSubject.beginService(tokens);
  }

  Token endService(Token tokens, int count) {
    logEndScope("service", "functions count = $count");
    return debugSubject.endService(tokens, count);
  }

  Token beginStruct(Token tokens) {
    logBeginScope("struct");
    return debugSubject.beginStruct(tokens);
  }

  Token endStruct(Token tokens, int count) {
    logEndScope("struct", "members count = $count");
    return debugSubject.endStruct(tokens, count);
  }

  Token beginIdentifier(Token tokens) {
    String identifierValue = tokens is! ErrorToken ? " [${tokens.value}]" : "";
    logBeginScope("indentifier$identifierValue");
    return debugSubject.beginIdentifier(tokens);
  }

  Token endIdentifier(Token tokens) {
    logEndScope("identifier");
    return debugSubject.endIdentifier(tokens);
  }

  Token beginFunction(Token tokens) {
    logBeginScope("function declaration");
    return debugSubject.beginFunction(tokens);
  }

  Token endFunction(Token tokens, int count) {
    logEndScope("function declaration", "formal parameters count = $count");
    return debugSubject.endFunction(tokens, count);
  }

  Token beginMember(Token tokens) {
    logBeginScope("member declaration");
    return debugSubject.beginMember(tokens);
  }

  Token endMember(Token tokens) {
    logEndScope("member declaration");
    return debugSubject.endMember(tokens);
  }

  Token beginType(Token tokens) {
    logBeginScope("type");
    return debugSubject.beginType(tokens);
  }

  Token endType(Token tokens) {
    logEndScope("type");
    return debugSubject.endType(tokens);
  }

  Token handleSimpleType(Token tokens) {
    log("Simple type");
    return debugSubject.handleSimpleType(tokens);
  }

  Token handlePointerType(Token tokens) {
    log("Pointer type");
    return debugSubject.handlePointerType(tokens);
  }

  Token handleListType(Token tokens) {
    log("List type");
    return debugSubject.handleListType(tokens);
  }

  Token beginFormal(Token tokens) {
    logBeginScope("formal parameter");
    return debugSubject.beginFormal(tokens);
  }

  Token endFormal(Token tokens) {
    logEndScope("formal parameter");
    return debugSubject.endFormal(tokens);
  }

  Token expectedTopLevel(Token tokens) {
    log("error: $tokens is not a top-level declaration");
    return debugSubject.expectedTopLevel(tokens);
  }

  Token expectedIdentifier(Token tokens) {
    log("error: $tokens is not an identifier");
    return debugSubject.expectedIdentifier(tokens);
  }

  Token expectedType(Token tokens) {
    log("error: $tokens is not a type");
    return debugSubject.expectedType(tokens);
  }

  Token expected(String string, Token tokens) {
    log("error: $tokens is not the symbol $string");
    return debugSubject.expected(string, tokens);
  }
}
