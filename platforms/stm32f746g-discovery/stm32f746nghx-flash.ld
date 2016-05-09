/*
 * Dartino linker script for STM32F746NGHx Device with 1024KByte FLASH and 320KByte RAM.
 *
 * The script has been adopted from the ST template to with
 *
 *  * Fixed allocation of TCM-RAM for network DMA.
 *  * Dartino static FFI section.
 */

/* Entry Point */
ENTRY(Reset_Handler)

/* Highest address of the user mode stack */
_estack = 0x20050000;    /* End of RAM */
/* Generate a link error if heap and stack don't fit into RAM */
_Min_Heap_Size = 0x400;  /* Required amount of heap  */
_Min_Stack_Size = 0x200; /* Required amount of stack */

/* Specify the memory areas */
MEMORY
{
  FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 1024K
  DMA_RxD(xrw) : ORIGIN = 0x20000000, LENGTH = 0xa0
  DMA_TxD(xrw) : ORIGIN = 0x200000a0, LENGTH = 0xa0
  DMA_RxB(xrw) : ORIGIN = 0x20000140, LENGTH = 0x1dc4
  DMA_TxB(xrw) : ORIGIN = 0x20001f04, LENGTH = 0x1dc4
  RAM (xrw) : ORIGIN = 0x20003cc8, LENGTH = 320K
}

/* Define output sections */
SECTIONS
{
  /* The startup code goes first into FLASH */
  .isr_vector :
  {
    . = ALIGN(4);
    KEEP(*(.isr_vector)) /* Startup code */
    . = ALIGN(4);
  } >FLASH

  /* The program code and other data goes into FLASH */
  .text :
  {
    . = ALIGN(4);
    *(.text)  /* .text sections (code) */
    *(.text*)  /* .text* sections (code) */
    *(.glue_7)  /* Glue arm to thumb code */
    *(.glue_7t)  /* Glue thumb to arm code */
    *(.eh_frame)

    KEEP (*(.init))
    KEEP (*(.fini))

    . = ALIGN(4);
    _etext = .;  /* Define a global symbols at end of code */
  } >FLASH

  /* Constant data goes into FLASH */
  .rodata :
  {
    . = ALIGN(4);
    *(.rodata)  /* .rodata sections (constants, strings, etc.) */
    *(.rodata*)  /* .rodata* sections (constants, strings, etc.) */
    . = ALIGN(4);
  } >FLASH

  /* Dartino FFI table goes into FLASH */
  .dartinoffi : {
    . = ALIGN(4);
    dartino_ffi_table = .;
    KEEP(*(.dartinoffi))
    QUAD(0)
    QUAD(0)
    . = ALIGN(4);
  } >FLASH

  .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } >FLASH
  .ARM : {
    __exidx_start = .;
    *(.ARM.exidx*)
    __exidx_end = .;
  } >FLASH

  .preinit_array     :
  {
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array*))
    PROVIDE_HIDDEN (__preinit_array_end = .);
  } >FLASH
  .init_array :
  {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT(.init_array.*)))
    KEEP (*(.init_array*))
    PROVIDE_HIDDEN (__init_array_end = .);
  } >FLASH
  .fini_array :
  {
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(SORT(.fini_array.*)))
    KEEP (*(.fini_array*))
    PROVIDE_HIDDEN (__fini_array_end = .);
  } >FLASH

  /* Used by the startup to initialize data */
  _sidata = LOADADDR(.data);

  /* Initialized data sections goes into RAM, load LMA copy after code */
  .data :
  {
    . = ALIGN(4);
    _sdata = .;  /* Create a global symbol at data start */
    *(.data)  /* .data sections */
    *(.data*)  /* .data* sections */

    . = ALIGN(4);
    _edata = .;  /* Define a global symbol at data end */
  } >RAM AT> FLASH

  /* Uninitialized data section */
  . = ALIGN(4);
  .bss :
  {
    /* This is used by the startup in order to initialize the .bss secion */
    _sbss = .;  /* Define a global symbol at bss start */
    __bss_start__ = _sbss;
    *(.bss)
    *(.bss*)
    *(COMMON)

    . = ALIGN(4);
    _ebss = .;  /* Define a global symbol at bss end */
    __bss_end__ = _ebss;
  } >RAM

  /* User_heap_stack section, used to check that there is enough RAM left */
  ._user_heap_stack :
  {
    . = ALIGN(8);
    PROVIDE ( end = . );
    PROVIDE ( _end = . );
    . = . + _Min_Heap_Size;
    . = . + _Min_Stack_Size;
    . = ALIGN(8);
  } >RAM

  /* Remove information from the standard libraries */
  /DISCARD/ :
  {
    libc.a ( * )
    libm.a ( * )
    libgcc.a ( * )
  }

  .ARM.attributes 0 : { *(.ARM.attributes) }

  .RxDescripSection : { *(.RxDescripSection) } >DMA_RxD
  .TxDescripSection : { *(.TxDescripSection) } >DMA_TxD
  .RxBUF : { *(.RxBUF) } >DMA_RxB
  .TxBUF : { *(.TxBUF) } >DMA_TxB
}
