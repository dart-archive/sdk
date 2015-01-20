LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := Fletch
LOCAL_CFLAGS := -DFLETCH32 -DANDROID -I../../ -std=c++11

LOCAL_SRC_FILES := \
	../../../src/shared/utils.cc \
	../../../src/shared/flags.cc \
	../../../src/shared/assert.cc \
	../../../src/shared/connection.cc \
	../../../src/shared/native_socket_linux.cc \
	../../../src/shared/native_process_posix.cc \
	../../../src/shared/native_socket_posix.cc \
	../../../src/shared/bytecodes.cc \
	../../../src/vm/event_handler.cc \
	../../../src/vm/scheduler.cc \
	../../../src/vm/platform_posix.cc \
	../../../src/vm/intrinsics.cc \
	../../../src/vm/service_api_impl.cc \
	../../../src/vm/thread_pool.cc \
	../../../src/vm/lookup_cache.cc \
	../../../src/vm/thread_posix.cc \
	../../../src/vm/weak_pointer.cc \
	../../../src/vm/session.cc \
	../../../src/vm/object_map.cc \
	../../../src/vm/fletch.cc \
	../../../src/vm/process.cc \
	../../../src/vm/natives.cc \
	../../../src/vm/program.cc \
	../../../src/vm/heap.cc \
	../../../src/vm/object.cc \
	../../../src/vm/event_handler_linux.cc \
	../../../src/vm/stack_walker.cc \
	../../../src/vm/port.cc \
	../../../src/vm/interpreter.cc \
	../../../src/vm/snapshot.cc \
	../../../src/vm/object_list.cc \
	../../../src/vm/object_memory.cc \
	../../../third_party/double-conversion/src/cached-powers.cc \
	../../../third_party/double-conversion/src/double-conversion.cc \
	../../../third_party/double-conversion/src/fast-dtoa.cc \
	../../../third_party/double-conversion/src/bignum-dtoa.cc \
	../../../third_party/double-conversion/src/fixed-dtoa.cc \
	../../../third_party/double-conversion/src/strtod.cc \
	../../../third_party/double-conversion/src/bignum.cc \
	../../../third_party/double-conversion/src/diy-fp.cc \

include $(BUILD_SHARED_LIBRARY)
