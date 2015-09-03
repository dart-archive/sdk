# main project for qemu-arm
TARGET := vexpress-a9

MODULES += \
	app/shell \
	app/fletch \
	lib/lwip \
	lib/libm \
	lib/evlog

GLOBAL_DEFINES += WITH_KERNEL_EVLOG=1

FLETCH_CONFIGURATION = LKVExpress

WITH_CPP_SUPPORT=true

#WITH_LINKER_GC := 0
