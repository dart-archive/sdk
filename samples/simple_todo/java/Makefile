# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

.PHONY: all servicec test clean

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

JAVA_SOURCES:=$(wildcard *.java fletch/*.java)

all: servicec SimpleTodo.jar jni/libfletch.${PLATFORM_LIB_SUFFIX} simple_todo.snapshot

servicec:
	$(FLETCH_BUILD_DIR)/fletch x-servicec file ../simple_todo.idl out ..

SimpleTodo.jar: $(JAVA_SOURCES)
	rm -rf classes
	mkdir classes
	$(JAVAC) -classpath none -d classes -implicit:none -source 8 -target 8 -sourcepath none -Werror $(JAVA_SOURCES)
	$(JAR) cfe SimpleTodo.jar SimpleTodo -C classes .
	rm -rf classes

jni/libfletch.so: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/todo_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ ${CPPFLAGS} -shared -o $@ $^

jni/libfletch.jnilib: jni/fletch_api_wrapper.o jni/fletch_service_api_wrapper.o jni/todo_service_wrapper.o ${FLETCH_BUILD_DIR}/libfletch.a
	g++ ${CPPFLAGS} -framework CoreFoundation -shared -o $@ $^

simple_todo.snapshot: ../simple_todo.dart
	cd ${FLETCH_DIR}; ${FLETCH_BUILD_DIR}/fletch export ${THIS_DIR}$< to ${THIS_DIR}$@

test: all
	LD_LIBRARY_PATH=jni \
	$(JAVA) -Djava.library.path=jni -jar SimpleTodo.jar simple_todo.snapshot

clean:
	rm -f SimpleTodo.jar jni/*.o jni/*.$(PLATFORM_LIB_SUFFIX) simple_todo.snapshot
