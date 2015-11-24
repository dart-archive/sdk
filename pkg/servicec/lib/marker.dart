// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'node.dart' show
    Node,
    NodeVisitor;

import 'errors.dart' show
    InternalCompilerError;

import 'package:compiler/src/tokens/token.dart' show
    Token;

// Marker nodes.
abstract class MarkerNode extends Node {
  Token token;

  MarkerNode(this.token);

  void accept(NodeVisitor visitor) {
    throw new InternalCompilerError("MarkerNode visited");
  }
}

class BeginFunctionMarker extends MarkerNode {
  BeginFunctionMarker(Token token)
    : super(token);
}

class BeginFieldMarker extends MarkerNode {
  BeginFieldMarker(Token token)
    : super(token);
}

class BeginFormalMarker extends MarkerNode {
  BeginFormalMarker(Token token)
    : super(token);
}

class BeginServiceMarker extends MarkerNode {
  BeginServiceMarker(Token token)
    : super(token);
}

class BeginStructMarker extends MarkerNode {
  BeginStructMarker(Token token)
    : super(token);
}

class BeginTypeMarker extends MarkerNode {
  BeginTypeMarker(Token token)
    : super(token);
}

class BeginUnionMarker extends MarkerNode {
  BeginUnionMarker(Token token)
    : super(token);
}
