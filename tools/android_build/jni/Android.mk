# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := fletch
LOCAL_CFLAGS := -DFLETCH32 -DANDROID -I../../ -std=c++11 -fno-stack-protector

LOCAL_SRC_FILES := \
	../../../src/shared/assert.cc \
	../../../src/shared/bytecodes.cc \
	../../../src/shared/connection.cc \
	../../../src/shared/flags.cc \
	../../../src/shared/native_process_posix.cc \
	../../../src/shared/native_socket_linux.cc \
	../../../src/shared/native_socket_posix.cc \
	../../../src/shared/utils.cc \
	../../../src/vm/event_handler.cc \
	../../../src/vm/event_handler_linux.cc \
	../../../src/vm/ffi.cc \
	../../../src/vm/fletch.cc \
	../../../src/vm/fletch_api_impl.cc \
	../../../src/vm/heap.cc \
	../../../src/vm/interpreter.cc \
	../../../src/vm/intrinsics.cc \
	../../../src/vm/lookup_cache.cc \
	../../../src/vm/natives.cc \
	../../../src/vm/object.cc \
	../../../src/vm/object_list.cc \
	../../../src/vm/object_map.cc \
	../../../src/vm/object_memory.cc \
	../../../src/vm/platform_posix.cc \
	../../../src/vm/port.cc \
	../../../src/vm/process.cc \
	../../../src/vm/program.cc \
	../../../src/vm/scheduler.cc \
	../../../src/vm/service_api_impl.cc \
	../../../src/vm/session.cc \
	../../../src/vm/snapshot.cc \
	../../../src/vm/stack_walker.cc \
	../../../src/vm/thread_pool.cc \
	../../../src/vm/thread_posix.cc \
	../../../src/vm/weak_pointer.cc \
	../../../third_party/double-conversion/src/bignum-dtoa.cc \
	../../../third_party/double-conversion/src/bignum.cc \
	../../../third_party/double-conversion/src/cached-powers.cc \
	../../../third_party/double-conversion/src/diy-fp.cc \
	../../../third_party/double-conversion/src/double-conversion.cc \
	../../../third_party/double-conversion/src/fast-dtoa.cc \
	../../../third_party/double-conversion/src/fixed-dtoa.cc \
	../../../third_party/double-conversion/src/strtod.cc \

include $(BUILD_STATIC_LIBRARY)
