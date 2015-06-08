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

CPPFLAGS=-fPIC -I../../../../include -I${JAVA_HOME}/include ${PLATFORM_INCLUDES}
THIS_DIR=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
FLETCH_BUILD=ReleaseX64
FLETCH_DIR=$(abspath ../../../..)
FLETCH_BUILD_DIR=$(abspath ${FLETCH_DIR}/out/${FLETCH_BUILD})

all: ConformanceTest.class SnapshotRunner.class fletch/ConformanceService.jar jni/libfletch.${PLATFORM_LIB_SUFFIX} conformance.snapshot

ConformanceTest.class: ConformanceTest.java
	javac $<

SnapshotRunner.class: SnapshotRunner.java
	javac $<

fletch/ConformanceService.jar: fletch/AgeStatsBuilder.class fletch/AgeStats.class fletch/ConformanceService.class fletch/ConsBuilder.class fletch/Cons.class fletch/FletchApi.class fletch/FletchServiceApi.class fletch/LargeBuilder.class fletch/Large.class fletch/NodeBuilder.class fletch/Node.class fletch/PersonBoxBuilder.class fletch/PersonBox.class fletch/PersonBuilder.class fletch/Person.class fletch/PersonList.class fletch/PersonListBuilder.class fletch/Reader.class fletch/ListReader.class fletch/MessageReader.class fletch/Segment.class fletch/SmallBuilder.class fletch/Small.class fletch/Uint8List.class fletch/Uint8ListBuilder.class fletch/BuilderSegment.class fletch/Builder.class fletch/MessageBuilder.class
	jar cvf $@ fletch/*.class

fletch/Builder.class: fletch/Builder.java
	javac $<

fletch/BuilderSegment.class: fletch/BuilderSegment.java
	javac $<

fletch/MessageBuilder.class: fletch/MessageBuilder.java
	javac $<

fletch/AgeStatsBuilder.class: fletch/AgeStatsBuilder.java
	javac $<

fletch/AgeStats.class: fletch/AgeStats.java
	javac $<

fletch/ConformanceService.class: fletch/ConformanceService.java
	javac $<

fletch/ConsBuilder.class: fletch/ConsBuilder.java
	javac $<

fletch/Cons.class: fletch/Cons.java
	javac $<

fletch/FletchApi.class: fletch/FletchApi.java
	javac $<

fletch/FletchServiceApi.class: fletch/FletchServiceApi.java
	javac $<

fletch/LargeBuilder.class: fletch/LargeBuilder.java
	javac $<

fletch/Large.class: fletch/Large.java
	javac $<

fletch/NodeBuilder.class: fletch/NodeBuilder.java
	javac $<

fletch/Node.class: fletch/Node.java
	javac $<

fletch/PersonBoxBuilder.class: fletch/PersonBoxBuilder.java
	javac $<

fletch/PersonBox.class: fletch/PersonBox.java
	javac $<

fletch/PersonBuilder.class: fletch/PersonBuilder.java
	javac $<

fletch/Person.class: fletch/Person.java
	javac $<

fletch/PersonList.class: fletch/PersonList.java
	javac $<

fletch/PersonListBuilder.class: fletch/PersonListBuilder.java
	javac $<

fletch/Reader.class: fletch/Reader.java
	javac $<

fletch/ListReader.class: fletch/ListReader.java
	javac $<

fletch/Segment.class: fletch/Segment.java
	javac $<

fletch/MessageReader.class: fletch/MessageReader.java
	javac $<

fletch/SmallBuilder.class: fletch/SmallBuilder.java
	javac $<

fletch/Small.class: fletch/Small.java
	javac $<

fletch/Uint8List.class: fletch/Uint8List.java
	javac $<

fletch/Uint8ListBuilder.class: fletch/Uint8ListBuilder.java
	javac $<

jni/libfletch.so: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/conformance_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ -shared -o $@ $^

jni/libfletch.jnilib: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/conformance_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ -framework CoreFoundation -shared -o $@ $^

conformance.snapshot: ../conformance_service_impl.dart
	# TODO: support the --out option in fletch/fletch-driver.
	# ${FLETCH_BUILD_DIR}/fletch_driver $< --out=$@
	# change to the fletch root so that fletch uses the right package directory.
	cd ${FLETCH_DIR}; ${FLETCH_BUILD_DIR}/dart --checked -p package pkg/fletchc/lib/fletchc.dart ${THIS_DIR}$< --out ${THIS_DIR}$@

test: all
	java -Djava.library.path=jni -ea -cp fletch/ConformanceService.jar:. ConformanceTest conformance.snapshot

clean:
	rm -f fletch/*.class fletch/ConformanceService.jar jni/*.o jni/*.so jni/*.jnilib *.class conformance.snapshot
