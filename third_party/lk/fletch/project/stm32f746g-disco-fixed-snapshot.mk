include project/target/stm32f746g-disco.mk

MODULES += app/fletch-fixed lib/gfx

EXTRA_LINKER_SCRIPTS += fletch/project/add-fletch-snapshot-section.ld

FLETCH_CONFIGURATION = LK
FLETCH_GYP_DEFINES = "LK_PROJECT=stm32f746g-disco-fletch LK_CPU=cortex-m4"

WITH_CPP_SUPPORT=true

# Console serial port is on pins PA9(TX) and PA10(RX)
