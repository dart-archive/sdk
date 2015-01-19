// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

void main() {
  var channel = new Channel(2);
  channel.send(1);
  channel.send(2);
  Expect.equals(1, channel.next);
  Expect.equals(2, channel.next);
}

