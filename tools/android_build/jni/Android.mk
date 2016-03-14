# Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := dartino-library
LOCAL_CFLAGS := \
  -DDARTINO32 \
  -DDARTINO_TARGET_OS_POSIX \
  -DDARTINO_TARGET_OS_LINUX \
  -DDARTINO_ENABLE_FFI \
  -DDARTINO_ENABLE_PRINT_INTERCEPTORS \
  -DDARTINO_ENABLE_LIVE_CODING \
  -DDARTINO_ENABLE_NATIVE_PROCESSES \
  -DANDROID \
  -I$(LOCAL_PATH)/../../../ -std=gnu++11

LOCAL_SRC_FILES := \
	../../../src/shared/assert.cc \
	../../../src/shared/bytecodes.cc \
	../../../src/shared/connection.cc \
	../../../src/shared/flags.cc \
	../../../src/shared/native_socket_linux.cc \
	../../../src/shared/native_socket_posix.cc \
	../../../src/shared/platform_linux.cc \
	../../../src/shared/platform_posix.cc \
	../../../src/shared/platform_vm.cc \
	../../../src/shared/utils.cc \
	../../../src/vm/debug_info.cc \
	../../../src/vm/event_handler.cc \
	../../../src/vm/event_handler_linux.cc \
	../../../src/vm/event_handler_posix.cc \
	../../../src/vm/ffi.cc \
	../../../src/vm/ffi_callback.cc \
	../../../src/vm/ffi_linux.cc \
	../../../src/vm/ffi_posix.cc \
	../../../src/vm/dartino.cc \
	../../../src/vm/dartino_api_impl.cc \
	../../../src/vm/gc_thread.cc \
	../../../src/vm/heap.cc \
	../../../src/vm/heap_validator.cc \
	../../../src/vm/interpreter.cc \
	../../../src/vm/intrinsics.cc \
	../../../src/vm/links.cc \
	../../../src/vm/lookup_cache.cc \
	../../../src/vm/log_print_interceptor.cc \
	../../../src/vm/message_mailbox.cc \
	../../../src/vm/native_process.cc \
	../../../src/vm/native_process_disabled.cc \
	../../../src/vm/natives.cc \
	../../../src/vm/natives_posix.cc \
	../../../src/vm/object.cc \
	../../../src/vm/object_list.cc \
	../../../src/vm/object_map.cc \
	../../../src/vm/object_memory.cc \
	../../../src/vm/object_memory_copying.cc \
	../../../src/vm/port.cc \
	../../../src/vm/process.cc \
	../../../src/vm/process_handle.cc \
	../../../src/vm/program.cc \
	../../../src/vm/program_folder.cc \
	../../../src/vm/scheduler.cc \
	../../../src/vm/selector_row.cc \
	../../../src/vm/service_api_impl.cc \
	../../../src/vm/session.cc \
	../../../src/vm/snapshot.cc \
	../../../src/vm/sort.cc \
	../../../src/vm/thread_pool.cc \
	../../../src/vm/thread_posix.cc \
	../../../src/vm/unicode.cc \
	../../../src/vm/vector.cc \
	../../../src/vm/void_hash_table.cc \
	../../../src/vm/weak_pointer.cc \
	../../../third_party/double-conversion/src/bignum-dtoa.cc \
	../../../third_party/double-conversion/src/bignum.cc \
	../../../third_party/double-conversion/src/cached-powers.cc \
	../../../third_party/double-conversion/src/diy-fp.cc \
	../../../third_party/double-conversion/src/double-conversion.cc \
	../../../third_party/double-conversion/src/fast-dtoa.cc \
	../../../third_party/double-conversion/src/fixed-dtoa.cc \
	../../../third_party/double-conversion/src/strtod.cc \

ifeq ($(TARGET_ARCH_ABI), armeabi-v7a)
  LOCAL_CFLAGS += -DDARTINO_TARGET_ARM
  LOCAL_SRC_FILES += \
    ../../../out/ReleaseXARMAndroid/obj/src/vm/dartino_vm.gen/generated.S \
    ../../../out/ReleaseXARMAndroid/gen/version.cc
endif

ifeq ($(TARGET_ARCH_ABI), x86)
  LOCAL_CFLAGS += -DDARTINO_TARGET_IA32
  LOCAL_SRC_FILES += \
    ../../../out/ReleaseIA32Android/obj/src/vm/dartino_vm.gen/generated.S \
    ../../../out/ReleaseIA32Android/gen/version.cc
endif

include $(BUILD_STATIC_LIBRARY)
