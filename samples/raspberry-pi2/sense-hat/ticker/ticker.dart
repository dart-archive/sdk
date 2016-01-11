// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Sample that runs on a Raspberry Pi with the Sense HAT add-on board.
// See: https://www.raspberrypi.org/products/sense-hat/.
//
// The sample will run a text message on the LED dot matrix.
library sample.ticker;

import 'package:os/os.dart' as os;
import 'package:raspberry_pi/sense_hat.dart';

import 'font.dart' show defaultFont;

// Entry point.
main() {
  // Instantiate the Sense HAT API.
  var hat = new SenseHat();

  // Start the ticker with negative offset so that the text starts
  // from off to the right.
  var offset = -hat.ledArray.width;
  var message = "Hello World!";
  while (true) {
    defaultFont.display(hat.ledArray, message, offset);
    offset += 1;
    if (offset > message.length * defaultFont.width) {
      // Reset.
      offset = -hat.ledArray.width;
    }
    os.sleep(70);
  }
}
