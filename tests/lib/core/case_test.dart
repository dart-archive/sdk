// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

void item(String from, String upper, String lower) {
  Expect.equals(from.toUpperCase(), upper);
  Expect.equals(from.toLowerCase(), lower);
  var strings = ["", "a", "A", ".", "\u{10400}"];
  for (String prefix in strings) {
    for (String affix in strings) {
      Expect.equals("$prefix$from$affix".toUpperCase(),
                    prefix.toUpperCase() + upper + affix.toUpperCase());
      Expect.equals("$prefix$from$affix".toLowerCase(),
                    prefix.toLowerCase() + lower + affix.toLowerCase());
    }
  }
}

void itemUnchanged(String from) {
  item(from, from, from);
}

void main() {
  item("foo", "FOO", "foo");
  item("Foo", "FOO", "foo");
  item("Schloß", "SCHLOSS", "schloß");
  itemUnchanged("");
  itemUnchanged(".");
  itemUnchanged("\u2603");
  itemUnchanged("\u{1f639}");
  item("\u{10400}", "\u{10400}", "\u{10428}");
  item("\u{10428}", "\u{10400}", "\u{10428}");
  item("\u0149", "\u02bcN", "\u0149");
  // That's Alpha-Iota in the upper case position, not AI.
  // See https://en.wikipedia.org/wiki/Iota_subscript.
  item("ᾳ", "ΑΙ", "ᾳ");
}
