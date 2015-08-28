# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

UNAME := $(shell uname)

ifeq ($(UNAME), Linux)
PLATFORM_INCLUDES=-I${JAVA_HOME}/include/linux
PLATFORM_LIB_SUFFIX=so
endif

ifeq ($(UNAME), Darwin)
PLATFORM_INCLUDES=-I${JAVA_HOME}/include/darwin
PLATFORM_LIB_SUFFIX=jnilib
endif

ARCH=64
FLETCH_BUILD=ReleaseX64

CPPFLAGS=-m${ARCH} -I../../../../include -I${JAVA_HOME}/include ${PLATFORM_INCLUDES}
THIS_DIR=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
FLETCH_DIR=$(abspath ../../../..)
FLETCH_BUILD_DIR=$(abspath ${FLETCH_DIR}/out/${FLETCH_BUILD})

JAR=${JAVA_HOME}/bin/jar
JAVA=${JAVA_HOME}/bin/java
JAVAC=${JAVA_HOME}/bin/javac

all: ConformanceTest.class SnapshotRunner.class DebugRunner.class fletch/ConformanceService.jar jni/libfletch.${PLATFORM_LIB_SUFFIX} conformance.snapshot

ConformanceTest.class: ConformanceTest.java
	$(JAVAC) $<

SnapshotRunner.class: SnapshotRunner.java
	$(JAVAC) $<

DebugRunner.class: DebugRunner.java
	$(JAVAC) $<

fletch/ConformanceService.jar: fletch/AgeStatsBuilder.class fletch/AgeStats.class fletch/ConformanceService.class fletch/ConsBuilder.class fletch/Cons.class fletch/FletchApi.class fletch/FletchServiceApi.class fletch/LargeBuilder.class fletch/Large.class fletch/NodeBuilder.class fletch/Node.class fletch/PersonBoxBuilder.class fletch/PersonBox.class fletch/PersonBuilder.class fletch/Person.class fletch/PersonList.class fletch/PersonListBuilder.class fletch/Reader.class fletch/ListReader.class fletch/MessageReader.class fletch/Segment.class fletch/SmallBuilder.class fletch/Small.class fletch/Uint8List.class fletch/Uint8ListBuilder.class fletch/BuilderSegment.class fletch/Builder.class fletch/MessageBuilder.class
	jar cvf $@ fletch/*.class

fletch/Builder.class: fletch/Builder.java
	$(JAVAC) $<

fletch/BuilderSegment.class: fletch/BuilderSegment.java
	$(JAVAC) $<

fletch/MessageBuilder.class: fletch/MessageBuilder.java
	$(JAVAC) $<

fletch/AgeStatsBuilder.class: fletch/AgeStatsBuilder.java
	$(JAVAC) $<

fletch/AgeStats.class: fletch/AgeStats.java
	$(JAVAC) $<

fletch/ConformanceService.class: fletch/ConformanceService.java
	$(JAVAC) $<

fletch/ConsBuilder.class: fletch/ConsBuilder.java
	$(JAVAC) $<

fletch/Cons.class: fletch/Cons.java
	$(JAVAC) $<

fletch/FletchApi.class: fletch/FletchApi.java
	$(JAVAC) $<

fletch/FletchServiceApi.class: fletch/FletchServiceApi.java
	$(JAVAC) $<

fletch/LargeBuilder.class: fletch/LargeBuilder.java
	$(JAVAC) $<

fletch/Large.class: fletch/Large.java
	$(JAVAC) $<

fletch/NodeBuilder.class: fletch/NodeBuilder.java
	$(JAVAC) $<

fletch/Node.class: fletch/Node.java
	$(JAVAC) $<

fletch/PersonBoxBuilder.class: fletch/PersonBoxBuilder.java
	$(JAVAC) $<

fletch/PersonBox.class: fletch/PersonBox.java
	$(JAVAC) $<

fletch/PersonBuilder.class: fletch/PersonBuilder.java
	$(JAVAC) $<

fletch/Person.class: fletch/Person.java
	$(JAVAC) $<

fletch/PersonList.class: fletch/PersonList.java
	$(JAVAC) $<

fletch/PersonListBuilder.class: fletch/PersonListBuilder.java
	$(JAVAC) $<

fletch/Reader.class: fletch/Reader.java
	$(JAVAC) $<

fletch/ListReader.class: fletch/ListReader.java
	$(JAVAC) $<

fletch/Segment.class: fletch/Segment.java
	$(JAVAC) $<

fletch/MessageReader.class: fletch/MessageReader.java
	$(JAVAC) $<

fletch/SmallBuilder.class: fletch/SmallBuilder.java
	$(JAVAC) $<

fletch/Small.class: fletch/Small.java
	$(JAVAC) $<

fletch/Uint8List.class: fletch/Uint8List.java
	$(JAVAC) $<

fletch/Uint8ListBuilder.class: fletch/Uint8ListBuilder.java
	$(JAVAC) $<

jni/libfletch.so: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/conformance_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ -m${ARCH} -shared -o $@ $^

jni/libfletch.jnilib: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/conformance_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ -m${ARCH} -framework CoreFoundation -shared -o $@ $^

conformance.snapshot: ../conformance_service_impl.dart
	cd ${FLETCH_DIR}; ${FLETCH_BUILD_DIR}/fletch compile-and-run -o ${THIS_DIR}$@ ${THIS_DIR}$<

test: all
	LD_LIBRARY_PATH=jni \
	$(JAVA) -Djava.library.path=jni -ea -cp fletch/ConformanceService.jar:. ConformanceTest conformance.snapshot

PORT=8123
debug: all
	LD_LIBRARY_PATH=jni \
	$(JAVA) -Djava.library.path=jni -ea -cp fletch/ConformanceService.jar:. ConformanceTest $(PORT)

clean:
	rm -f fletch/*.class fletch/ConformanceService.jar jni/*.o jni/*.so jni/*.jnilib *.class conformance.snapshot
