// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// API for accessing the devices on the Raspberry Pi Sense HAT.
///
/// Currently this has only been tested with a Raspberry Pi 2 and the Sense HAT.
///
/// The following sample code show how to access the devices on the Raspberry Pi
/// Sense HAT.
///
/// ```
/// import 'dart:fletch.os' as os;
/// import 'package:raspberry_pi/sense_hat.dart';
///
/// void draw(hat, c1, c2, c3) {
///   for (int i = 0; i < 8; i++) {
///     hat.setPixel(i, i, c1);
///     hat.setPixel(i, 7 - i, c1);
///   }
///   for (int i = 0; i < 8; i++) {
///     hat.setPixel(3, i, c2);
///     hat.setPixel(4, i, c2);
///   }
///   for (int i = 0; i < 8; i++) {
///     hat.setPixel(i, 3, c3);
///     hat.setPixel(i, 4, c3);
///   }
/// }
///
/// main() {
///   var hat = new SenseHat();
///
///   while (true) {
///     draw(hat, Color.RED, Color.GREEN, Color.BLUE);
///     os.sleep(200);
///     draw(hat, Color.GREEN, Color.BLUE, Color.RED);
///     os.sleep(200);
///     draw(hat, Color.BLUE, Color.RED, Color.GREEN);
///     os.sleep(200);
///     var temp = hat.readTemperature();
///     var humidity = hat.readHumidity();
///     var pressure = hat.readPressure();
///     var accel = hat.readAccel();
///     print('${accel.pitch} ${accel.roll} $temp $humidity $pressure');
///   }
/// }
/// ```
library raspberry_pi.sense_hat;

import 'dart:fletch.ffi';

import 'package:i2c/i2c.dart';
import 'package:i2c/devices/hts221.dart';
import 'package:i2c/devices/lps25h.dart';
import 'package:i2c/devices/lsm9ds1.dart';

// Foreign functions used.
final ForeignFunction _open = ForeignLibrary.main.lookup('open');
final ForeignFunction _mmap = ForeignLibrary.main.lookup('mmap');

/// Pixel color.
class Color {
  static const RED = const Color(0xff, 0x00, 0x00);
  static const GREEN = const Color(0x00, 0xff, 0x00);
  static const BLUE = const Color(0x00, 0x000, 0xff);
  static const BLACK = const Color(0x00, 0x00, 0x00);
  static const WHITE = const Color(0xff, 0xff, 0xff);

  final int r;
  final int g;
  final int b;

  const Color(this.r, this.g, this.b);

  // RGB565
  int get _rgb565 => ((r & 0xf8) << 8) | ((g & 0xfb) << 3) | ((b & 0xf8) >> 3);

  String toString() => 'Color: R=$r, G=$g, B=$b';
}

/// Sense HAT 8x8 LED array
class SenseHatLEDArray {
  final height = 8;
  final width = 8;
  final bytesPerPixel = 2;

  var _fd;
  var _fbMem;

  SenseHatLEDArray() {
    // From /usr/include/x86_64-linux-gnu/bits/fcntl-linux.h.
    const int oRDWR = 02;  // O_RDWR
    // Found from C code 'printf("%x\n", O_SYNC);'.
    const int oSync = 0x101000;  // O_SYNC

    // The Sense HAT frame buffer is always /dev/fb1.
    var devFbPath = new ForeignMemory.fromStringAsUTF8('/dev/fb1');
    _fd = _open.icall$2(devFbPath, oRDWR | oSync);
    devFbPath.free();

    // From /usr/include/x86_64-linux-gnu/bits/mman-linux.h.
    const int protRead = 0x1;  // PROT_READ.
    const int protWrite = 0x2;  // PROT_WRITE.
    const int mapShared = 0x01;  // MAP_SHARED.

    ForeignPointer _addr;
    var memSize = bytesPerPixel * height * width;
    _addr = _mmap.pcall$6(0, memSize, protRead | protWrite, mapShared, _fd, 0);
    _fbMem = new ForeignMemory.fromAddress(_addr.address, memSize);
  }

  // Offset into the memory area for the pixel (x, y).
  int _offset(int x, int y) => x * bytesPerPixel + y * width * bytesPerPixel;

  setPixel(int x, int y, Color color) {
    if (x < 0 || x >= width || y < 0 || y >= height) throw new ArgumentError();
    _fbMem.setUint16(_offset(x, y), color._rgb565);
  }
}

class SenseHat {
  SenseHatLEDArray _ledArray;
  HTS221 _hts221;
  LPS25H _lps25h;
  LSM9DS1 _lsm9ds1;

  /// Access to the a Raspberry Pi Sense HAT.
  SenseHat() {
    _ledArray = new SenseHatLEDArray();

    // Connect to the I2C bus.
    var busAddress = new I2CBusAddress(1);
    var bus = busAddress.open();

    // Connect to and power on I2C devices on the Sense HAT.
    _hts221 = new HTS221(new I2CDevice(0x5f, bus));
    _lps25h = new LPS25H(new I2CDevice(0x5c, bus));
    _lsm9ds1 = new LSM9DS1(accelGyroDevice: new I2CDevice(0x6a, bus),
                           magnetDevice: new I2CDevice(0x1c, bus));
    _hts221.powerOn();
    _lps25h.powerOn();
    _lsm9ds1.powerOn();
  }

  SenseHatLEDArray get ledArray => _ledArray;
  HTS221 get hts221 => _hts221;
  LPS25H get lps25h => _lps25h;
  LSM9DS1 get lsm9ds1 => _lsm9ds1;

  // Set a pixel in the Sense HAT 8x8 LED array.
  void setPixel(int x, int y, Color color) {
    _ledArray.setPixel(x, y, color);
  }

  /// Read the current temperature value.
  double readTemperature() => _hts221.readTemperature();

  /// Read the humidity temperature value.
  double readHumidity() => _hts221.readHumidity();

  /// Read the current pressure value.
  double readPressure() => _lps25h.readPressure();

  /// Returns `true` if new a gyroscope measurement is ready.
  bool hasGyroMeasurement() => _lsm9ds1.hasGyroMeasurement();

  /// Returns `true` if new a accelerometer measurement is ready.
  bool hasAccelMeasurement() => _lsm9ds1.hasAccelMeasurement();

  /// Returns `true` if new a magnetometer measurement is ready.
  bool hasMagnetMeasurement() => _lsm9ds1.hasMagnetMeasurement();

  /// Read the current gyroscope measurement.
  GyroMeasurement readGyro() => _lsm9ds1.readGyro();

  /// Read the current accelerometer measurement.
  AccelMeasurement readAccel() => _lsm9ds1.readAccel();

  /// Read the current magnetometer measurement.
  MagnetMeasurement readMagnet() => _lsm9ds1.readMagnet();
}

