include project/target/stm32746g-eval2.mk

MODULES += app/fletch lib/libm app/shell

FLETCH_CONFIGURATION = LK
FLETCH_GYP_DEFINES = "LK_PROJECT=stm32746g-fletch LK_CPU=cortex-m4"

WITH_CPP_SUPPORT=true

# Console serial port is on pins PA9(TX) and PA10(RX)
