// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library power_management;

import "dart-ext:native/power_management_extension_lib";

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
int disableSleep(String reason) native 'PowerManagementExtension_DisableSleep';

/// Enable sleep again.
///
/// Pass the return value from [disableSleep] as the [disableId]
/// argument.
void enableSleep(disableId) native 'PowerManagementExtension_EnableSleep';
