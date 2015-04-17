// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

bool isImmutable(Object object) {
  return _isImmutable(object);
}

bool _isImmutable(String string) native;
