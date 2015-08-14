# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

INCLUDES=-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux
CPPFLAGS=-fPIC -I../../../../include ${INCLUDES}
FLETCH_BUILD_DIR=../../../../out/ReleaseX64

all: PerformanceTest.class SnapshotRunner.class fletch/PerformanceService.jar jni/libfletch.so performance.snapshot

PerformanceTest.class: PerformanceTest.java
	javac $<

SnapshotRunner.class: SnapshotRunner.java
	javac $<

fletch/PerformanceService.jar: fletch/PerformanceService.class fletch/FletchApi.class fletch/FletchServiceApi.class fletch/Reader.class fletch/Builder.class fletch/BuilderSegment.class fletch/ListBuilder.class fletch/ListReader.class fletch/Segment.class fletch/MessageReader.class fletch/MessageBuilder.class fletch/TreeNode.class fletch/TreeNodeList.class fletch/TreeNodeListBuilder.class fletch/TreeNodeBuilder.class
	jar cvf $@ $^

fletch/PerformanceService.class: fletch/PerformanceService.java
	javac $<

fletch/FletchApi.class: fletch/FletchApi.java
	javac $<

fletch/FletchServiceApi.class: fletch/FletchServiceApi.java
	javac $<

fletch/Builder.class: fletch/Builder.java
	javac $<

fletch/BuilderSegment.class: fletch/BuilderSegment.java
	javac $<

fletch/Reader.class: fletch/Reader.java
	javac $<

fletch/ListReader.class: fletch/ListReader.java
	javac $<

fletch/ListBuilder.class: fletch/ListBuilder.java
	javac $<

fletch/MessageBuilder.class: fletch/MessageBuilder.java
	javac $<

fletch/Segment.class: fletch/Segment.java
	javac $<

fletch/MessageReader.class: fletch/MessageReader.java
	javac $<

fletch/TreeNode.class: fletch/TreeNode.java
	javac $<

fletch/TreeNodeList.class: fletch/TreeNodeList.java
	javac $<

fletch/TreeNodeListBuilder.class: fletch/TreeNodeListBuilder.java
	javac $<

fletch/TreeNodeBuilder.class: fletch/TreeNodeBuilder.java
	javac $<

jni/libfletch.so: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/performance_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ -shared -o $@ $^

performance.snapshot: ../performance_service_impl.dart
	${FLETCH_BUILD_DIR}/fletch $< --out=$@

test: all
	LD_LIBRARY_PATH=jni \
	java -Djava.library.path=jni -cp fletch/PerformanceService.jar:. PerformanceTest performance.snapshot

clean:
	rm -f fletch/*.class fletch/PerformanceService.jar jni/*.o jni/*.so *.class performance.snapshot
