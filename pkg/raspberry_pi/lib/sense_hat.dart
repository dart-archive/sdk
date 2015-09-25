// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// API for accessing the devices on the Raspberry Pi Sense HAT add-on board.
/// See: https://www.raspberrypi.org/products/sense-hat/.
///
/// Currently this has only been tested with a Raspberry Pi 2 and the Sense HAT.
///
/// The following sample code show how to access the devices on the Raspberry Pi
/// Sense HAT.
///
/// ```
/// import 'package:os/os.dart' as os;
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
///     draw(hat, Color.red, Color.green, Color.blue);
///     os.sleep(200);
///     draw(hat, Color.green, Color.blue, Color.red);
///     os.sleep(200);
///     draw(hat, Color.blue, Color.red, Color.green);
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
  static const red = const Color(0xff, 0x00, 0x00);
  static const green = const Color(0x00, 0xff, 0x00);
  static const blue = const Color(0x00, 0x000, 0xff);
  static const black = const Color(0x00, 0x00, 0x00);
  static const white = const Color(0xff, 0xff, 0xff);

  final int r;
  final int g;
  final int b;

  const Color(this.r, this.g, this.b);

  // RGB565
  int get _rgb565 => ((r & 0xf8) << 8) | ((g & 0xfb) << 3) | ((b & 0xf8) >> 3);

  String toString() => 'Color: R=$r, G=$g, B=$b';
}

/// Sense HAT 8x8 LED array.
class SenseHatLEDArray {
  final height = 8;
  final width = 8;
  final bytesPerPixel = 2;

  var _fd;
  var _fbMem;

  SenseHatLEDArray._() {
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

  /// Set a pixel in the LED array.
  ///
  /// Set the pixel at position ([x], [y]) to the color [color].
  setPixel(int x, int y, Color color) {
    if (x < 0 || x >= width) throw new RangeError.range(x, 0, width, 'x');
    if (y < 0 || y >= height) throw new RangeError.range(y, 0, height, 'y');
    _fbMem.setUint16(_offset(x, y), color._rgb565);
  }

  /// Clears the LED array.
  ///
  /// All the leds in the array is set to [color], which defaults to
  /// [Color.black].
  void clear([color = Color.black]) {
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        setPixel(x, y, color);
      }
    }
  }
}

/// API to the Raspberry Pi Sense HAT add-on board.
///
/// Instantiating this class will open the I2C bus to communicate with
/// the devices for the board.
///
/// The properties [hts221], [lps25h] and [lsm9ds1] provide
/// access to the sensor APIs. The property [ledArray] provide access to the
/// 8 x 8 LED array.
///
/// For the most common sensor APIs, this object provide direct access to
/// some of the measurements, e.g. through the methods [readTemperature] and
/// [readHumidity].
class SenseHat {
  SenseHatLEDArray _ledArray;
  HTS221 _hts221;
  LPS25H _lps25h;
  LSM9DS1 _lsm9ds1;

  /// Access to the a Raspberry Pi Sense HAT.
  SenseHat() {
    _ledArray = new SenseHatLEDArray._();

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

  /// API for the LED array.
  SenseHatLEDArray get ledArray => _ledArray;

  /// Device API for the HTS221 temperature and humidity sensor.
  HTS221 get temperatureHumiditySensor => _hts221;

  /// Device API for the LPS25H pressure sensor.
  LPS25H get pressureSensor => _lps25h;

  /// Device API for the LSM9DS1 accelerometer, gyroscope and magnetometer
  /// sensor.
  LSM9DS1 get orientationSensor => _lsm9ds1;

  /// Set a pixel in the Sense HAT 8x8 LED array.
  ///
  /// Set the pixel at position ([x], [y]) to the color [color].
  void setPixel(int x, int y, Color color) {
    _ledArray.setPixel(x, y, color);
  }

  /// Clears the LED array.
  ///
  /// All the leds in the array is set to [color], which defaults to
  /// [Color.black].
  void clear([color = Color.black]) {
    _ledArray.clear();
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
