A preliminary API providing I2C support for Linux.

Currently this has only been tested with a Raspberry Pi 2.

Usage
-----

The following sample code show how to access the HTS221 humidity and
temperature sensor and the LPS25H pressure sensor on a Raspberry Pi Sense
HAT.

```dart

import 'package:i2c/i2c.dart';
import 'package:i2c/devices/hts221.dart';
import 'package:i2c/devices/lps25h.dart';
import 'package:os/os.dart' as os;
main() {
  The Raspberry Pi 2 has I2C bus 1.
  var busAddress = new I2CBusAddress(1);
  var bus = busAddress.open();

  // Connect to the two devices.
  var hts221 = new HTS221(new I2CDevice(0x5f, bus));
  var lps25h = new LPS25H(new I2CDevice(0x5c, bus));
  hts221.powerOn();
  lps25h.powerOn();
  while (true) {
    print('Temperature: ${hts221.readTemperature()}');
    print('Humidity: ${hts221.readHumidity()}');
    print('Pressure: ${lps25h.readPressure()}');
    os.sleep(1000);
  }
}
```
Reporting issues
----------------

Please file an issue [in the issue tracker](https://github.com/dart-lang/fletch/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
