A preliminary API providing access to the operating system when Fletch is
running on a Posix platform.

Usage
-----

```dart
import 'package:os/os.dart';

main() {
  SystemInformation si = sys.info();
  print('Hello from ${si.operatingSystemName} running on ${si.nodeName}.');
}
```

Reporting issues
----------------

Please file an issue [in the issue tracker](https://github.com/dart-lang/fletch/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
