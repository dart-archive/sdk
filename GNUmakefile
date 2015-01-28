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

# TODO(ahe): Change to out/clang after fixing echo service test.
CLANG_OUT=clang_out

all: DebugIA32 DebugX64 ReleaseIA32 ReleaseX64

DebugIA32: out/DebugIA32/build.ninja $(CLANG_OUT)/DebugIA32/build.ninja
	$(quiet)ninja $(ninja_verbose) -C out/DebugIA32
	$(quiet)ninja $(ninja_verbose) -C $(CLANG_OUT)/DebugIA32

ReleaseIA32: out/ReleaseIA32/build.ninja $(CLANG_OUT)/ReleaseIA32/build.ninja
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseIA32
	$(quiet)ninja $(ninja_verbose) -C $(CLANG_OUT)/ReleaseIA32

DebugX64: out/DebugX64/build.ninja $(CLANG_OUT)/DebugX64/build.ninja
	$(quiet)ninja $(ninja_verbose) -C out/DebugX64
	$(quiet)ninja $(ninja_verbose) -C $(CLANG_OUT)/DebugX64

ReleaseX64: out/ReleaseX64/build.ninja $(CLANG_OUT)/ReleaseX64/build.ninja
	$(quiet)ninja $(ninja_verbose) -C out/ReleaseX64
	$(quiet)ninja $(ninja_verbose) -C $(CLANG_OUT)/ReleaseX64

gyp_files = \
  common.gypi \
  fletch.gyp \
  src/compiler/compiler.gyp \
  src/double_conversion.gyp \
  src/shared/shared.gyp \
  src/vm/vm.gyp \
  tests/service_tests/service_tests.gyp

out/ReleaseIA32/build.ninja out/DebugIA32/build.ninja out/ReleaseX64/build.ninja out/DebugX64/build.ninja: $(gyp_files)
	$(quiet)./third_party/gyp/gyp $(gyp_verbose) --depth=. -Icommon.gypi \
		-Dclang=0 -Goutput_dir=out \
		--format=ninja fletch.gyp

$(CLANG_OUT)/ReleaseIA32/build.ninja $(CLANG_OUT)/DebugIA32/build.ninja $(CLANG_OUT)/ReleaseX64/build.ninja $(CLANG_OUT)/DebugX64/build.ninja: $(gyp_files)
	$(quiet)./third_party/gyp/gyp $(gyp_verbose) --depth=. -Icommon.gypi \
		-Dclang=1 -Goutput_dir=$(CLANG_OUT) \
		--format=ninja fletch.gyp

.PHONY: all DebugIA32 DebugX64 ReleaseIA32 ReleaseX64
