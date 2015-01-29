# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

LOCAL_PATH := $(call my-dir)

# Service shared library.
include $(CLEAR_VARS)
LOCAL_MODULE := fletch
LOCAL_CFLAGS := -DFLETCH32 -DANDROID
LOCAL_LDLIBS := -llog -ldl -rdynamic

LOCAL_SRC_FILES := \
	fletch_api_wrapper.cc \
	fletch_service_api_wrapper.cc \
	echo_service_wrapper.cc

LOCAL_C_INCLUDES += $(LOCAL_PATH)
LOCAL_C_INCLUDES += ../../../../include
LOCAL_STATIC_LIBRARIES := fletch-library

include $(BUILD_SHARED_LIBRARY)

$(call import-module, ../../../../tools/android_build/jni)
