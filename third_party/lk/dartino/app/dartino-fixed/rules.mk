LOCAL_DIR := $(GET_LOCAL_DIR)

DARTINO_BASE := $(BUILDROOT)/..

MODULE := $(LOCAL_DIR)

MODULE_DEPS += \
	lib/libm \
	$(DARTINO_BASE)

MODULE_SRCS += \
	$(LOCAL_DIR)/dartino_runner.c \
	$(LOCAL_DIR)/missing.c \
	$(LOCAL_DIR)/dartino_program.S

MODULE_INCLUDES += $(DARTINO_BASE)

include make/module.mk
