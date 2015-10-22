# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

.PHONY: all generate test clean

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

CPPFLAGS=-fPIC -m${ARCH} -I../../../include -I${JAVA_HOME}/include ${PLATFORM_INCLUDES}
THIS_DIR=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
FLETCH_DIR=$(abspath ../../..)
FLETCH_BUILD_DIR=$(abspath ${FLETCH_DIR}/out/${FLETCH_BUILD})

JAR=${JAVA_HOME}/bin/jar
JAVA=${JAVA_HOME}/bin/java
JAVAC=${JAVA_HOME}/bin/javac

all: generate SimpleTodo.class SnapshotRunner.class fletch/TodoService.jar jni/libfletch.${PLATFORM_LIB_SUFFIX} simple_todo.snapshot

SimpleTodo.class: SimpleTodo.java
	$(JAVAC) $<

SnapshotRunner.class: SnapshotRunner.java
	$(JAVAC) $<

fletch/TodoService.jar: fletch/BoxString.class fletch/BoxStringBuilder.class fletch/Builder.class fletch/BuilderSegment.class fletch/FletchApi.class fletch/FletchServiceApi.class fletch/ListBuilder.class fletch/ListReader.class fletch/MessageBuilder.class fletch/MessageReader.class fletch/Reader.class fletch/Segment.class fletch/TodoItem.class fletch/TodoItemBuilder.class fletch/TodoService.class fletch/Uint16List.class fletch/Uint16ListBuilder.class
	$(JAR) cvf $@ $^

fletch/BoxString.class: fletch/BoxString.java
	$(JAVAC) $<

fletch/BoxStringBuilder.class: fletch/BoxStringBuilder.java
	$(JAVAC) $<

fletch/Builder.class: fletch/Builder.java
	$(JAVAC) $<

fletch/BuilderSegment.class: fletch/BuilderSegment.java
	$(JAVAC) $<

fletch/FletchApi.class: fletch/FletchApi.java
	$(JAVAC) $<

fletch/FletchServiceApi.class: fletch/FletchServiceApi.java
	$(JAVAC) $<

fletch/ListBuilder.class: fletch/ListBuilder.java
	$(JAVAC) $<

fletch/ListReader.class: fletch/ListReader.java
	$(JAVAC) $<

fletch/MessageBuilder.class: fletch/MessageBuilder.java
	$(JAVAC) $<

fletch/MessageReader.class: fletch/MessageReader.java
	$(JAVAC) $<

fletch/Reader.class: fletch/Reader.java
	$(JAVAC) $<

fletch/Segment.class: fletch/Segment.java
	$(JAVAC) $<

fletch/TodoItem.class: fletch/TodoItem.java
	$(JAVAC) $<

fletch/TodoItemBuilder.class: fletch/TodoItemBuilder.java
	$(JAVAC) $<

fletch/TodoService.class: fletch/TodoService.java
	$(JAVAC) $<

fletch/Uint16List.class: fletch/Uint16List.java
	$(JAVAC) $<

fletch/Uint16ListBuilder.class: fletch/Uint16ListBuilder.java
	$(JAVAC) $<

generate:
	$(FLETCH_BUILD_DIR)/fletch x-servicec file ../simple_todo.idl out ..

jni/libfletch.so: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/todo_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ ${CPPFLAGS} -shared -o $@ $^

jni/libfletch.jnilib: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/todo_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ ${CPPFLAGS} -framework CoreFoundation -shared -o $@ $^

simple_todo.snapshot: ../simple_todo.dart
	cd ${FLETCH_DIR}; ${FLETCH_BUILD_DIR}/fletch export ${THIS_DIR}$< to ${THIS_DIR}$@

test: all
	LD_LIBRARY_PATH=jni \
	$(JAVA) -Djava.library.path=jni -cp fletch/TodoService.jar:. SimpleTodo simple_todo.snapshot

clean:
	rm -f fletch/*.class fletch/TodoService.jar jni/*.o jni/*.so jni/*.jnilib *.class simple_todo.snapshot
