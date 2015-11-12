A preliminary API providing access to Raspberry Pi 2 specific hardware features
such as onboard LEDs. Also provides an API to the Sense HAT shield.

Usage
-----

```dart
import 'package:raspberry_pi/raspberry_pi.dart';

main() {
  // Initialize Raspberry Pi and configure the activity LED to be GPIO
  // controlled.
  RaspberryPi pi = new RaspberryPi();
  pi.leds.activityLED.setMode(OnboardLEDMode.gpio);

  // Turn LED on
  pi.leds.activityLED.on();
}
```

Reporting issues
----------------

Please file an issue [in the issue tracker](https://github.com/dart-lang/fletch/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
