A preliminary API providing file access when Fletch is running on a Posix
platform.

Usage
-----

```dart
import 'package:file/file.dart';

void main() {
  var file = new File.temporary("/tmp/file_test");
  // Use file.read() or file.write()
  file.close();
  File.delete(file.path);
```

Reporting issues
----------------

Please file an issue [in the issue tracker](https://github.com/dart-lang/fletch/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
