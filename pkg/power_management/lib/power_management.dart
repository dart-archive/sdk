// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library power_management;

import 'dart:async';

import 'package:power_management/src/native_extension_api.dart'
    deferred as native_extension_api;

/// Initialize the power management API.
///
/// This function must be called before using any of the other
/// functions.
Future initPowerManagement() async {
  await native_extension_api.loadLibrary();
}

/// Disables sleep.
///
/// The [reason] is used to indicate why sleep needs to be disabled. On
/// some systems this string can be surfaced to the user to tell why the
/// system is not entering sleep mode.
///
/// Returns an id which must be used to re-enable sleep.
///
/// On most systems normal sleep behavior will be re-established if the
/// program calling `disableSleep` terminates before calling `enableSleep`.
///
/// Before using this function the function `initPowerManagement` must
/// have been called.
int disableSleep(String reason) => native_extension_api.disableSleep(reason);

/// Enable sleep again.
///
/// Pass the return value from [disableSleep] as the [disableId]
/// argument.
///
/// Before using this function the function `initPowerManagement` must
/// have been called.
void enableSleep(disableId) => native_extension_api.enableSleep(disableId);
