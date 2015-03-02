# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

INCLUDES=-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux
CPPFLAGS=-fPIC -I../../../../include ${INCLUDES}
FLETCH_BUILD_DIR=../../../../out/ReleaseX64

all: ConformanceTest.class SnapshotRunner.class fletch/ConformanceService.jar jni/libfletch.so conformance.snapshot

ConformanceTest.class: ConformanceTest.java
	javac $<

SnapshotRunner.class: SnapshotRunner.java
	javac $<

fletch/ConformanceService.jar: fletch/ConformanceService.class fletch/FletchApi.class fletch/FletchServiceApi.class
	jar cvf $@ $^

fletch/ConformanceService.class: fletch/ConformanceService.java
	javac $<

fletch/FletchApi.class: fletch/FletchApi.java
	javac $<

fletch/FletchServiceApi.class: fletch/FletchServiceApi.java
	javac $<

jni/libfletch.so: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/conformance_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ -shared -o $@ $^

conformance.snapshot: ../conformance_service_impl.dart
	${FLETCH_BUILD_DIR}/fletch $< --out=$@

test: all
	LD_LIBRARY_PATH=jni java -ea -cp fletch/ConformanceService.jar:. ConformanceTest conformance.snapshot

clean:
	rm -f fletch/*.class fletch/ConformanceService.jar jni/*.o jni/*.so *.class conformance.snapshot
