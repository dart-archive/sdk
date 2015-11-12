Provides access to controlling GPIO pins.

Currently this has only been tested with a Raspberry Pi 2.

Usage
-----

```dart
import 'package:gpio/gpio.dart';
import 'package:raspberry_pi/raspberry_pi.dart';

main() {
  // GPIO pin constants.
  const int pin = 16;

  // Initialize Raspberry Pi and configure the pins.
  RaspberryPi pi = new RaspberryPi();
  PiMemoryMappedGPIO gpio = pi.memoryMappedGPIO;
  gpio.setMode(pin, Mode.input);

  // Access pin
  gpio.setPin(pin, true);
```

See ```/samples/raspberry_pi/``` for additional details.

Reporting issues
----------------

Please file an issue [in the issue tracker](https://github.com/dart-lang/fletch/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
