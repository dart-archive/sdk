// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library driver.cmd_line_utils;

int getPortNumberFromArg(String arg, String helpText) {
  final int portNumber = int.parse(arg, onError: (source) {
    print("Required argument <port number> was not a number.");
    print("");
    print(helpText);
    return -1;
    });

  if (portNumber <= 1024) {
    print("You supplied a <port number> of $portNumber.");
    print("Only ports over 1024 are supported.");
    return -1;
  }
  return portNumber;
}
