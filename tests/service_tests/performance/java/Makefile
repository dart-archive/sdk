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

CPPFLAGS=-fPIC -m${ARCH} -I../../../../include -I${JAVA_HOME}/include ${PLATFORM_INCLUDES}
THIS_DIR=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
FLETCH_DIR=$(abspath ../../../..)
FLETCH_BUILD_DIR=$(abspath ${FLETCH_DIR}/out/${FLETCH_BUILD})

JAR=${JAVA_HOME}/bin/jar
JAVA=${JAVA_HOME}/bin/java
JAVAC=${JAVA_HOME}/bin/javac

all: PerformanceTest.class SnapshotRunner.class fletch/PerformanceService.jar jni/libfletch.${PLATFORM_LIB_SUFFIX} performance.snapshot

PerformanceTest.class: PerformanceTest.java
	$(JAVAC) $<

SnapshotRunner.class: SnapshotRunner.java
	$(JAVAC) $<

fletch/PerformanceService.jar: fletch/PerformanceService.class fletch/FletchApi.class fletch/FletchServiceApi.class fletch/Reader.class fletch/Builder.class fletch/BuilderSegment.class fletch/ListBuilder.class fletch/ListReader.class fletch/Segment.class fletch/MessageReader.class fletch/MessageBuilder.class fletch/TreeNode.class fletch/TreeNodeList.class fletch/TreeNodeListBuilder.class fletch/TreeNodeBuilder.class
	$(JAR) cvf $@ $^

fletch/PerformanceService.class: fletch/PerformanceService.java
	$(JAVAC) $<

fletch/FletchApi.class: fletch/FletchApi.java
	$(JAVAC) $<

fletch/FletchServiceApi.class: fletch/FletchServiceApi.java
	$(JAVAC) $<

fletch/Builder.class: fletch/Builder.java
	$(JAVAC) $<

fletch/BuilderSegment.class: fletch/BuilderSegment.java
	$(JAVAC) $<

fletch/Reader.class: fletch/Reader.java
	$(JAVAC) $<

fletch/ListReader.class: fletch/ListReader.java
	$(JAVAC) $<

fletch/ListBuilder.class: fletch/ListBuilder.java
	$(JAVAC) $<

fletch/MessageBuilder.class: fletch/MessageBuilder.java
	$(JAVAC) $<

fletch/Segment.class: fletch/Segment.java
	$(JAVAC) $<

fletch/MessageReader.class: fletch/MessageReader.java
	$(JAVAC) $<

fletch/TreeNode.class: fletch/TreeNode.java
	$(JAVAC) $<

fletch/TreeNodeList.class: fletch/TreeNodeList.java
	$(JAVAC) $<

fletch/TreeNodeListBuilder.class: fletch/TreeNodeListBuilder.java
	$(JAVAC) $<

fletch/TreeNodeBuilder.class: fletch/TreeNodeBuilder.java
	$(JAVAC) $<

jni/libfletch.so: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/performance_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ ${CPPFLAGS} -shared -o $@ $^

jni/libfletch.jnilib: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/performance_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ ${CPPFLAGS} -framework CoreFoundation -shared -o $@ $^

performance.snapshot: ../performance_service_impl.dart
	cd ${FLETCH_DIR}; ${FLETCH_BUILD_DIR}/fletch compile-and-run -o ${THIS_DIR}$@ ${THIS_DIR}$<

test: all
	LD_LIBRARY_PATH=jni \
	$(JAVA) -Djava.library.path=jni -cp fletch/PerformanceService.jar:. PerformanceTest performance.snapshot

clean:
	rm -f fletch/*.class fletch/PerformanceService.jar jni/*.o jni/*.so jni/*.jnilib *.class performance.snapshot
