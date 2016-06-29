// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:stm32/stm32f746g_disco.dart';
import 'package:nucleo_iks01a1/nucleo_iks01a1.dart';

main() {
  print('Reading sensors on a X-NUCLEO-IKS01A1 expansion board');
  STM32F746GDiscovery disco = new STM32F746GDiscovery();
  NucleoIKS01A1 sensors = new NucleoIKS01A1(disco.i2c1);

  var hts221 = sensors.hts221;
  hts221.powerOn();
  var lps25h = sensors.lps25h;
  lps25h.powerOn();
  var lsm6ds0 = sensors.lsm6ds0;
  var lis3mdl = sensors.lis3mdl;
  lsm6ds0.powerOn();
  lis3mdl.powerOn();

  while (true) {
    double t1 = hts221.readTemperature();
    double h = hts221.readHumidity();
    double t2 = lps25h.readTemperature();
    double p = lps25h.readPressure();
    AccelMeasurement a = lsm6ds0.readAccel();
    MagnetMeasurement m = lis3mdl.readMagnet();
    print('Temperature: $t1, Humidity: $h');
    print('Temperature: $t2, Pressure: $p');
    print('$a');
    print('$m');
    sleep(5000);
  }
}
