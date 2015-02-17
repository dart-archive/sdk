# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

INCLUDES=-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux
CPPFLAGS=-fPIC -I../../../../include ${INCLUDES}
FLETCH_BUILD_DIR=../../../../out/ReleaseX64

all: Echo.class SnapshotRunner.class fletch/EchoService.jar jni/libfletch.so echo.snapshot

Echo.class: Echo.java
	javac $<

SnapshotRunner.class: SnapshotRunner.java
	javac $<

fletch/EchoService.jar: fletch/EchoService.class fletch/FletchApi.class fletch/FletchServiceApi.class
	jar cvf $@ $^

fletch/EchoService.class: fletch/EchoService.java
	javac $<

fletch/FletchApi.class: fletch/FletchApi.java
	javac $<

fletch/FletchServiceApi.class: fletch/FletchServiceApi.java
	javac $<

jni/libfletch.so: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/echo_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ -shared -o $@ $^

echo.snapshot: ../echo.dart
	${FLETCH_BUILD_DIR}/fletch $< --out=$@

test: all
	LD_LIBRARY_PATH=jni java -cp fletch/EchoService.jar:. Echo echo.snapshot

clean:
	rm fletch/*.class jni/*.o jni/*.so *.class echo.snapshot jni/*.a
