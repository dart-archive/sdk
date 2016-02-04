// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Defines exception handlers for ARM.

#include <stdio.h>
#include <stdint.h>

// Defines 'read only' structure member permissions
#define __IM volatile const
// Defines 'write only' structure member permissions
#define __OM volatile
// Defines 'read / write' structure member permissions
#define __IOM volatile

typedef struct {
  // CPUID Base Register
  __IM  uint32_t CPUID;
  // Interrupt Control and State Register
  __IOM uint32_t ICSR;
  // Vector Table Offset Register
  __IOM uint32_t VTOR;
  // Application Interrupt and Reset Control Register
  __IOM uint32_t AIRCR;
  // System Control Register
  __IOM uint32_t SCR;
  // Configuration Control Register
  __IOM uint32_t CCR;
  // System Handlers Priority Registers (4-7, 8-11, 12-15)
  __IOM uint8_t  SHPR[12U];
  // System Handler Control and State Register
  __IOM uint32_t SHCSR;
  // Configurable Fault Status Register
  __IOM uint32_t CFSR;
  // HardFault Status Register
  __IOM uint32_t HFSR;
  // Debug Fault Status Register
  __IOM uint32_t DFSR;
  // MemManage Fault Address Register
  __IOM uint32_t MMFAR;
  // BusFault Address Register
  __IOM uint32_t BFAR;
  // Auxiliary Fault Status Register
  __IOM uint32_t AFSR;
  // Processor Feature Register
  __IM  uint32_t ID_PFR[2U];
  // Debug Feature Register
  __IM  uint32_t ID_DFR;
  // Auxiliary Feature Register
  __IM  uint32_t ID_AFR;
  // Memory Model Feature Register
  __IM  uint32_t ID_MFR[4U];
  // Instruction Set Attributes Register
  __IM  uint32_t ID_ISAR[5U];
  uint32_t RESERVED0[1U];
  // Cache Level ID register
  __IM  uint32_t CLIDR;
  // Cache Type register
  __IM  uint32_t CTR;
  // Cache Size ID Register
  __IM  uint32_t CCSIDR;
  // Cache Size Selection Register
  __IOM uint32_t CSSELR;
  // Coprocessor Access Control Register
  __IOM uint32_t CPACR;
  uint32_t RESERVED3[93U];
  // Software Triggered Interrupt Register
  __OM  uint32_t STIR;
  uint32_t RESERVED4[15U];
  // Media and VFP Feature Register 0
  __IM  uint32_t MVFR0;
  // Media and VFP Feature Register 1
  __IM  uint32_t MVFR1;
  // Media and VFP Feature Register 1
  __IM  uint32_t MVFR2;
  uint32_t RESERVED5[1U];
  // I-Cache Invalidate All to PoU
  __OM  uint32_t ICIALLU;
  uint32_t RESERVED6[1U];
  // I-Cache Invalidate by MVA to PoU
  __OM  uint32_t ICIMVAU;
  // D-Cache Invalidate by MVA to PoC
  __OM  uint32_t DCIMVAC;
  // D-Cache Invalidate by Set-way
  __OM  uint32_t DCISW;
  // D-Cache Clean by MVA to PoU
  __OM  uint32_t DCCMVAU;
  // D-Cache Clean by MVA to PoC
  __OM  uint32_t DCCMVAC;
  // D-Cache Clean by Set-way
  __OM  uint32_t DCCSW;
  // D-Cache Clean and Invalidate by MVA to PoC
  __OM  uint32_t DCCIMVAC;
  // D-Cache Clean and Invalidate by Set-way
  __OM  uint32_t DCCISW;
  uint32_t RESERVED7[6U];
  // Instruction Tightly-Coupled Memory Control Register
  __IOM uint32_t ITCMCR;
  // Data Tightly-Coupled Memory Control Registers
  __IOM uint32_t DTCMCR;
  // AHBP Control Register
  __IOM uint32_t AHBPCR;
  // L1 Cache Control Register
  __IOM uint32_t CACR;
  // AHB Slave Control Register
  __IOM uint32_t AHBSCR;
  uint32_t RESERVED8[1U];
  // Auxiliary Bus Fault Status Register
  __IOM uint32_t ABFSR;
} SCB_Type;

// System Control Space Base Address.
#define SCS_BASE (0xE000E000UL)

// System Control Block Base Address.
#define SCB_BASE (SCS_BASE + 0x0D00UL)

// SCB configuration struct.
#define SCB ((SCB_Type*) SCB_BASE)

struct arm_cm_exception_frame {
    uint32_t r4;
    uint32_t r5;
    uint32_t r6;
    uint32_t r7;
    uint32_t r8;
    uint32_t r9;
    uint32_t r10;
    uint32_t r11;
    uint32_t r0;
    uint32_t r1;
    uint32_t r2;
    uint32_t r3;
    uint32_t r12;
    uint32_t lr;
    uint32_t pc;
    uint32_t psr;
};

static void halt() {
  printf("Halt - spinning forever\n");
  for (;;) {}
}

static void dump_frame(const struct arm_cm_exception_frame *frame) {
  printf("Exception frame at %p\n", frame);
  printf("\tr0: 0x%08x, r1: 0x%08x, r2: 0x%08x, r3: 0x%08x, r4: 0x%08x\n",
         frame->r0, frame->r1, frame->r2, frame->r3, frame->r4);
  printf("\tr5: 0x%08x, r6: 0x%08x, r7: 0x%08x, r8: 0x%08x, r9: 0x%08x\n",
         frame->r5, frame->r6, frame->r7, frame->r8, frame->r9);
  printf("\tr10: 0x%08x, r11: 0x%08x, r12: 0x%08x\n",
         frame->r10, frame->r11, frame->r12);
  printf("\tlr: 0x%08x pc: 0x%08x, psr: 0x%08x\n",
         frame->lr, frame->pc, frame->psr);
}

static void hardfault(struct arm_cm_exception_frame *frame) {
  printf("hardfault: ");
  dump_frame(frame);

  printf("HFSR 0x%x\n", SCB->HFSR);

  halt();
}

static void memmanage(struct arm_cm_exception_frame *frame) {
  printf("memmanage: ");
  dump_frame(frame);

  uint32_t mmfsr = SCB->CFSR & 0xff;

  // IACCVIOL
  if (mmfsr & (1 << 0)) {
    printf("instruction fault\n");
  }
  // DACCVIOL
  if (mmfsr & (1 << 1)) {
    printf("data fault\n");
  }
  // MUNSTKERR
  if (mmfsr & (1 << 3)) {
    printf("fault on exception return\n");
  }
  // MSTKERR
  if (mmfsr & (1 << 4)) {
    printf("fault on exception entry\n");
  }
  // MLSPERR
  if (mmfsr & (1 << 5)) {
    printf("fault on lazy fpu preserve\n");
  }
  // MMARVALID
  if (mmfsr & (1 << 7)) {
    printf("fault address 0x%x\n", SCB->MMFAR);
  }

  halt();
}

static void usagefault(struct arm_cm_exception_frame *frame) {
  printf("usagefault: ");
  dump_frame(frame);

  halt();
}

static void busfault(struct arm_cm_exception_frame *frame) {
  printf("busfault: ");
  dump_frame(frame);

  halt();
}

void HardFault_Handler(void) __attribute__((naked));

void HardFault_Handler(void) {
  __asm__ volatile(
      "push	{r4-r11};"
      "mov	r0, sp;"
      "b		%0;" : : "i" (hardfault)
  );
  __builtin_unreachable();
}

void MemManage_Handler(void) __attribute__((naked));

void MemManage_Handler(void) {
  __asm__ volatile(
      "push	{r4-r11};"
      "mov	r0, sp;"
      "b		%0;" : : "i" (memmanage)
  );
  __builtin_unreachable();
}

void BusFault_Handler(void) __attribute__((naked));

void BusFault_Handler(void) {
  __asm__ volatile(
      "push	{r4-r11};"
      "mov	r0, sp;"
      "b		%0;" : : "i" (busfault)
  );
  __builtin_unreachable();
}

void __attribute__((naked)) UsageFault_Handler(void) {
  __asm__ volatile(
      "push	{r4-r11};"
      "mov	r0, sp;"
      "b		%0;" : : "i" (usagefault)
  );
  __builtin_unreachable();
}
