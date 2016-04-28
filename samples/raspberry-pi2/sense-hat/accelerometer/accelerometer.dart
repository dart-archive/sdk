// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Sample that runs on a Raspberry Pi 2 with the Sense HAT add-on board.
// See: https://www.raspberrypi.org/products/sense-hat/.
//
// The sample will indicate the current pitch and roll from the
// accelerometer on the LED array as line segments.
library sample.accelerometer;

import 'dart:dartino';

import 'package:raspberry_pi/sense_hat.dart';
import 'package:i2c/devices/lsm9ds1.dart';

// Entry point.
main() {
  // Instantiate the Sense HAT API.
  SenseHat hat = new SenseHat();

  // Show the splash screen animation and run the program.
  splashScreen(hat);
  run(hat);
}

// Run the sample which will indicate the current pitch and roll from the
// accelerometer on the LED array.
void run(SenseHat hat) {
  int pitch = 0; // [-3..3]
  int roll = 0; // [-3..3]

  int trimValue(double value) {
    int result = value ~/ 15.0;
    if (result < -3) result = -3;
    if (result > 3) result = 3;
    return result;
  }

  void draw() {
    hat.clear();
    if (pitch == 0 && roll == 0) {
      drawSegment(hat.ledArray, Direction.north, 0);
      drawSegment(hat.ledArray, Direction.south, 0);
    } else {
      if (pitch != 0) {
        drawSegment(
          hat.ledArray,
          pitch < 0 ? Direction.north : Direction.south,
          pitch.abs());
      }
      if (roll != 0) {
        drawSegment(
          hat.ledArray,
          roll < 0 ? Direction.west : Direction.east,
          roll.abs());
      }
    }
  }

  // Draw the initial state.
  draw();

  while (true) {
    // Read the accelerometer and update the display it one of the values
    // changed.
    AccelMeasurement accel = hat.readAccel();
    int p = trimValue(accel.pitch);
    int r = trimValue(accel.roll);
    if (p != pitch || r != roll) {
      pitch = p;
      roll = r;
      draw();
    }
  }
}

// The drawSegment function below can draw some preconfigured lines in
// the LED array. The segments are indicated with W, G, B and R in the
// figure below.
//
//     RRRRRRRR
//     .BBBBBB.
//     ..GGGG..
//     ...WW...
//     ........
//     ........
//     ........
//     ........
//
// The figure shows the segments in direction north. drawSegment can
// draw in all four directions north, east, south and west.
//
// The data in the classes `Direction`, `Point` and `SegmentData` helps
// drawing these segments.
enum Direction {
  north,
  east,
  south,
  west,
}

class Point {
  final int x;
  final int y;
  const Point(this.x, this.y);
}

// Each segment direction (north, east, south and west) has an origin
// which is indicated in the figure below.
//
//     ........
//     ........
//     ........
//     ...NE...
//     ...WS...
//     ........
//     ........
//     ........
//
// The origin combined with a direction defines the starting point for
// each segment. From the starting point the step define how to move
// when drawing.
class SegmentData {
  final Point origin;
  final Point direction;
  final Point step;
  const SegmentData(this.origin, this. direction, this.step);
}

const segmentData = const <Direction, SegmentData> {
  Direction.north:
    const SegmentData(
      const Point(3, 4), const Point(-1, 1), const Point(1, 0)),
  Direction.east:
    const SegmentData(
      const Point(4, 4), const Point(1, 1), const Point(0, -1)),
  Direction.south:
    const SegmentData(
      const Point(4, 3), const Point(1, -1), const Point(-1, 0)),
  Direction.west:
    const SegmentData(
      const Point(3, 3), const Point(-1, -1), const Point(0, 1)),
};

void drawSegment(SenseHatLEDArray ledArray,
                 Direction direction,
                 int segment,
                 {Color color}) {
  const defaultSegmentColor =
      const <Color>[Color.white, Color.green, Color.blue, Color.red];

  if (color == null) color = defaultSegmentColor[segment];
  int length = (segment + 1) * 2;
  SegmentData info = segmentData[direction];
  int x = info.origin.x + info.direction.x * segment;
  int y = info.origin.y + info.direction.y * segment;
  for (int i = 0; i < length; i++) {
    ledArray.setPixel(x, y, color);
    x += info.step.x;
    y += info.step.y;
  }
}

// Do a small splash-screen animation.
void splashScreen(SenseHat hat) {
  const allDirections =
      const <Direction>[
          Direction.north, Direction.east, Direction.south, Direction.west];

  for (int s = 0; s < 4; s++) {
    for (Direction d in allDirections) {
      drawSegment(hat.ledArray, d, s);
    }
    sleep(200);
  }
  for (int s = 0; s < 4; s++) {
    for (Direction d in allDirections) {
      drawSegment(hat.ledArray, d, s, color: Color.black);
    }
    sleep(200);
  }
  for (int s = 0; s < 4; s++) {
    for (Direction d in allDirections) {
      drawSegment(hat.ledArray, d, s);
    }
    sleep(200);
    for (Direction d in allDirections) {
      drawSegment(hat.ledArray, d, s, color: Color.black);
    }
  }
}
