import 'dart:dartino';

import 'package:i2c/devices/mpl3115a2.dart';
import 'package:stm32/lcd.dart';
import 'package:stm32/stm32f746g_disco.dart';

main() {
  var board = new STM32F746GDiscovery();
  var sensor = new MPL3115A2(board.i2c1);
  var display = board.frameBuffer;

  display
    ..foregroundColor = Color.blue
    ..backgroundColor = Color.white
    ..clear()
    ..writeText(25, 25, 'Reading the MPL3115A2 i2c sensor...');

  var top = 90;
  var bottom = 230;
  var maxLength = 300;
  var temperatureList = <double>[];
  var pressureList = <double>[];

  sensor.powerOn();
  var lowTemperature = sensor.temperature - 3;
  var highTemperature = sensor.temperature + 2;
  var lowPressure = sensor.pressure - 40;
  var highPressure = sensor.pressure + 60;
  for (int index = 0; index < maxLength; ++index) {
    var x = 25 + index;
    display.drawLine(x, top, x, bottom, Color.black);
  }
  while (true) {
    var temperature = sensor.temperature;
    temperatureList.add(temperature);
    if (temperatureList.length > maxLength) temperatureList.removeAt(0);
    if (lowTemperature > temperature) lowTemperature = temperature;
    if (highTemperature < temperature) highTemperature = temperature;

    var pressure = sensor.pressure;
    pressureList.add(pressure);
    if (pressureList.length > maxLength) pressureList.removeAt(0);
    if (lowPressure > pressure) lowPressure = pressure;
    if (highPressure < pressure) highPressure = pressure;

    display
      ..foregroundColor = Color.blue
      ..writeText(25, 45, '  temperature: $temperature C  ')
      ..drawCircle(32, 50, 3, Color.lightRed)
      ..foregroundColor = Color.blue
      ..writeText(25, 65, '  pressure:    $pressure Pa    ')
      ..drawCircle(32, 70, 3, Color.lightGreen);

    for (int index = 0; index < temperatureList.length; ++index) {
      var x = 25 + index;
      display.drawLine(x, top, x, bottom, Color.black);
      int y = bottom -
          ((temperatureList[index] - lowTemperature) *
              (bottom - top) ~/
              (highTemperature - lowTemperature));
      display.drawPixel(x, y, Color.lightRed);
      y = bottom -
          ((pressureList[index] - lowPressure) *
              (bottom - top) ~/
              (highPressure - lowPressure));
      display.drawPixel(x, y, Color.lightGreen);
    }

    sleep(500);
  }
}
