@echo off
REM Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
REM for details. All rights reserved. Use of this source code is governed by a
REM BSD-style license that can be found in the LICENSE file.

set GYP_CROSSCOMPILE="1"
python "%~dp0\gyp-windows.py" %*
