import 'dart:dartino';

import 'package:i2c/devices/mpl3115a2.dart';
import 'package:stm32/lcd.dart';
import 'package:stm32/stm32f746g_disco.dart';

main() {
  var disco = new STM32F746GDiscovery();
  var sensor = new MPL3115A2(disco.i2c1);
  var display = disco.frameBuffer;

  display.foregroundColor = Color.blue;
  display.backgroundColor = Color.white;
  display.clear();
  display.writeText(25, 25, 'Reading the MPL3115A2 i2c sensor...');

  sensor.powerOn();
  while (true) {
    display.writeText(25, 45, '  temperature: ${sensor.temperature} C  ');
    display.writeText(25, 65, '  pressure:    ${sensor.pressure} Pa    ');
    sleep(500);
  }
}
