# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

INCLUDES=-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux
CPPFLAGS=-fPIC -I../../../../include ${INCLUDES}
FLETCH_BUILD_DIR=../../../../out/ReleaseX64
FLETCH_BASE_LIB=${FLETCH_BUILD_DIR}/obj/src/vm/libfletch_vm_base.a
FLETCH_LIB=${FLETCH_BUILD_DIR}/obj/src/vm/libfletch_vm.a
FLETCH_SHARED_LIB=${FLETCH_BUILD_DIR}/obj/src/shared/libfletch_shared.a
FLETCH_DOUBLE_LIB=${FLETCH_BUILD_DIR}/obj/src/libdouble_conversion.a


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

jni/libfletch_vm.a: ${FLETCH_BASE_LIB} ${FLETCH_LIB} ${FLETCH_SHARED_LIB} ${FLETCH_DOUBLE_LIB}
	echo -e "create jni/libfletch_vm.a\naddlib ${FLETCH_BASE_LIB}\naddlib ${FLETCH_LIB}\naddlib ${FLETCH_SHARED_LIB}\naddlib ${FLETCH_DOUBLE_LIB}\nsave\nend" | ar -M

jni/libfletch.so: jni/libfletch_vm.a jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/echo_service_wrapper.o
	g++ -shared -o $@ $^ ${FLETCH_BASE_LIB} -rdynamic -ldl -lpthread -ldl -lstdc++

echo.snapshot: ../echo.dart
	${FLETCH_BUILD_DIR}/fletch $< --out=$@

test: all
	LD_LIBRARY_PATH=jni java -cp fletch/EchoService.jar:. Echo echo.snapshot

clean:
	rm fletch/*.class jni/*.o jni/*.so *.class echo.snapshot jni/*.a
