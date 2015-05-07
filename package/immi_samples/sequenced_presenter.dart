// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library immi_samples.sequenced_presenter;

import 'package:immi/immi.dart';

abstract class SequencedPresenter<T extends Node> {
  // Returns presentation graph for valid index otherwise null.
  T presentAt(int index);
}
