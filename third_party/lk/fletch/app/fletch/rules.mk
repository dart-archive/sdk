LOCAL_DIR := $(GET_LOCAL_DIR)

FLETCH_BASE := $(BUILDROOT)/../../../

MODULE := $(LOCAL_DIR)

MODULE_DEPS += \
	lib/libm \
	lib/minip

MODULE_SRCS += \
	$(LOCAL_DIR)/fletch_runner.c \
	$(LOCAL_DIR)/missing.c \

MODULE_INCLUDES += $(FLETCH_BASE)

ifneq ($(DEBUG),)
EXTRA_OBJS += $(FLETCH_BASE)/out/Debug$(FLETCH_CONFIGURATION)/libfletch.a
else
EXTRA_OBJS += $(FLETCH_BASE)/out/Release$(FLETCH_CONFIGURATION)/libfletch.a
endif

force_fletch_target:

$(FLETCH_BASE)/out/Debug$(FLETCH_CONFIGURATION)/libfletch.a: force_fletch_target
	ninja -C $(FLETCH_BASE) lk -t clean
	GYP_DEFINES=$(FLETCH_GYP_DEFINES) ninja -C $(FLETCH_BASE) lk
	ninja -C $(FLETCH_BASE)/out/Debug$(FLETCH_CONFIGURATION)/ libfletch -t clean
	ninja -C $(FLETCH_BASE)/out/Debug$(FLETCH_CONFIGURATION)/ libfletch

$(FLETCH_BASE)/out/Release$(FLETCH_CONFIGURATION)/libfletch.a: force_fletch_target
	ninja -C $(FLETCH_BASE) lk -t clean
	GYP_DEFINES=$(FLETCH_GYP_DEFINES) ninja -C $(FLETCH_BASE) lk
	ninja -C $(FLETCH_BASE)/out/Release$(FLETCH_CONFIGURATION)/ libfletch -t clean
	ninja -C $(FLETCH_BASE)/out/Release$(FLETCH_CONFIGURATION)/ libfletch

# put arch local .S files here if developing memcpy/memmove

include make/module.mk
