import 'dart:dartino';
import 'package:stm32/stm32f411re_nucleo.dart';
import 'package:stm32/gpio.dart';

main() {
  STM32F411RENucleo nucleo = new STM32F411RENucleo();
  STM32Gpio gpio = nucleo.gpio;
  // Initialize all PWM pins
  var pins = [
    gpio.initPwmOutput(STM32F411RENucleo.D3),
    gpio.initPwmOutput(STM32F411RENucleo.D5),
    gpio.initPwmOutput(STM32F411RENucleo.D6),
    gpio.initPwmOutput(STM32F411RENucleo.D9),
    gpio.initPwmOutput(STM32F411RENucleo.D10),
    gpio.initPwmOutput(STM32F411RENucleo.D11)
  ];
  // Set different frequences on each pin.
  // Note: these that share a timer will share the frequency.
  for(int i = 0; i < pins.length; i++){
    pins[i].prescaler = (i + 1) * 100 - 1;
    pins[i].period = 9999;
    pins[i].output(i * 1000 + 1000);
  }
  while(true){
    sleep(1);
  }
}
