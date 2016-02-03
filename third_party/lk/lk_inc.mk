# the top level directory that all paths are relative to
LKMAKEROOT := .

# paths relative to LKMAKEROOT where additional modules should be searched
LKINC := dartino

# the path relative to LKMAKEROOT where the main lk repository lives
LKROOT := lk-downstream

# set the directory relative to LKMAKEROOT where output will go
BUILDROOT ?= out

# set the default project if no args are passed
DEFAULT_PROJECT ?= qemu-virt-dartino

TOOLCHAIN_PREFIX := ../gcc-arm-embedded/linux/gcc-arm-embedded/bin/arm-none-eabi-
