LOCAL_PATH := $(call my-dir)

# Fletch static library.
include $(CLEAR_VARS)
LOCAL_MODULE := fletch-library
LOCAL_SRC_FILES := ../../../../../tools/android_build/obj/local/$(TARGET_ARCH_ABI)/libfletch.a
include $(PREBUILT_STATIC_LIBRARY)

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
