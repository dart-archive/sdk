# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# The V=1 flag on command line makes us verbosely print command lines.
ifdef V
  quiet=
  gyp_verbose=-dincludes
  ninja_verbose=-v
else
  quiet=@
  gyp_verbose=
  ninja_verbose=-v
endif

OS := $(shell uname -s)

all: DebugIA32 DebugX64 ReleaseIA32 ReleaseX64

DebugIA32: out/DebugIA32/build.ninja out/DebugIA32Clang/build.ninja /usr/include/stdio.h
ifeq ($(OS),Linux)
	$(quiet)ninja $(ninja_verbose) -C out/DebugIA32
	$(quiet)ninja $(ninja_verbose) -C out/DebugIA32Asan
endif
	$(quiet)ninja $(ninja_verbose) -C out/DebugIA32Clang
	$(quiet)ninja $(ninja_verbose) -C out/DebugIA32ClangAsan

ReleaseIA32: out/ReleaseIA32/build.ninja out/ReleaseIA32Clang/build.ninja /usr/include/stdio.h
ifeq ($(OS),Linux)
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseIA32
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseIA32Asan
endif
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseIA32Clang
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseIA32ClangAsan

DebugX64: out/DebugX64/build.ninja out/DebugX64Clang/build.ninja /usr/include/stdio.h
ifeq ($(OS),Linux)
	$(quiet)ninja $(ninja_verbose) -C out/DebugX64
	$(quiet)ninja $(ninja_verbose) -C out/DebugX64Asan
endif
	$(quiet)ninja $(ninja_verbose) -C out/DebugX64Clang
	$(quiet)ninja $(ninja_verbose) -C out/DebugX64ClangAsan

ReleaseX64: out/ReleaseX64/build.ninja out/ReleaseX64Clang/build.ninja /usr/include/stdio.h
ifeq ($(OS),Linux)
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseX64
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseX64Asan
endif
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseX64Clang
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseX64ClangAsan

gyp_files = \
  common.gypi \
  fletch.gyp \
  src/double_conversion.gyp \
  src/shared/shared.gyp \
  src/vm/vm.gyp

out/ReleaseIA32/build.ninja out/DebugIA32/build.ninja out/ReleaseX64/build.ninja out/DebugX64/build.ninja: $(gyp_files)
	$(quiet)ninja

ifeq ($(OS),Darwin)
/usr/include/stdio.h:
	xcode-select --install
endif

.PHONY: all DebugIA32 DebugX64 ReleaseIA32 ReleaseX64
