// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Describes the different target device types for the fletch system.
library fletch_device_type;

enum DeviceType {
  embedded,
  mobile,
}

/// Parses [s] into a [DeviceType] enum value.
///
/// Returns `null` if [s] is not recognized as the name of
/// a valid [DeviceType] value.
DeviceType parseDeviceType(String s) {
  switch (s) {
    case "embedded": return DeviceType.embedded;
    case "mobile": return DeviceType.mobile;
  }
  return null;
}

/// Returns the String representation of a [DeviceType] enum value.
String unParseDeviceType(DeviceType deviceType) {
  switch (deviceType) {
    case DeviceType.embedded: return "embedded";
    case DeviceType.mobile: return "mobile";
  }
  throw new ArgumentError("Unrecognized device type '$deviceType'");
}
