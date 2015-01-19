#!/usr/bin/env sh
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

DIR=`dirname $0`
dart --enable-async --checked $DIR/bin/main.dart
