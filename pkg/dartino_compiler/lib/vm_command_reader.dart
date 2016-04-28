// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dartino.vm_session;

class SessionCommandTransformerBuilder
    extends CommandTransformerBuilder<Pair<int, ByteData>> {

  Pair<int, ByteData> makeCommand(int code, ByteData payload) {
    return new Pair<int, ByteData>(code, payload);
  }
}
