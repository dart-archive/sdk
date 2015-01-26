# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

all: out/ReleaseIA32/build.ninja
	ninja -C out/ReleaseIA32

gyp_files = \
  common.gypi \
  fletch.gyp \
  src/compiler/compiler.gyp \
  src/double_conversion.gyp \
  src/shared/shared.gyp \
  src/vm/vm.gyp \
  tests/service_tests/service_tests.gyp

out/ReleaseIA32/build.ninja: $(gyp_files)
	./third_party/gyp/gyp --depth=. -Icommon.gypi --format=ninja fletch.gyp

.PHONY: all
