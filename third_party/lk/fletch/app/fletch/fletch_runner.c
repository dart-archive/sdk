// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <app.h>
#include <fletch_api.h>
#include <endian.h>

union IEEEl2bits {
	long double	e;
	struct {
#if LITTLE_ENDIAN
		unsigned int	manl	:32;
		unsigned int	manh	:20;
		unsigned int	exp	:11;
		unsigned int	sign	:1;
#else
		unsigned int		sign	:1;
		unsigned int		exp	:11;
		unsigned int		manh	:20;
		unsigned int		manl	:32;
#endif
	} bits;
};

int __signbit(double val) {
  union IEEEl2bits as_bits;
  as_bits.e = val;
  return as_bits.bits.sign;
}

int read_snapshot(unsigned char** snapshot) {
    printf("READY TO READ SNAPSHOT DATA.\n");
    printf("STEP1: size.\n");
    char size_buf[10];
    int pos = 0;
    while ((size_buf[pos++] = getchar()) != '\n') {
      putchar(size_buf[pos-1]);
    }
    if (pos > 9) abort();
    size_buf[pos] = 0;
    int size = atoi(size_buf);
    unsigned char* result = malloc(size);
    printf("\nSTEP2: reading snapshot of %d bytes.\n", size);
    int status = 0;
    for (pos = 0; pos < size; pos++, status++) {
      result[pos] = getchar();
      if (status == 1024) {
	putchar('.');
	status = 0;
      }	
    }
    printf("\nSNAPSHOT READ.\n");
    *snapshot = result;
    return size;
}
	    
void run_snapshot(unsigned char* snapshot, int size) {
    printf("STARTING fletch-vm...\n");
    FletchSetup();
    printf("LOADING snapshot...\n");
    FletchProgram program = FletchLoadSnapshot(snapshot, size);
    free(snapshot);
    printf("RUNNING program...\n");
    FletchRunMain(program);
    printf("DELETING program...\n");
    FletchDeleteProgram(program);
    printf("TEARING DOWN fletch-vm...\n");
    FletchTearDown();
}

#if defined(WITH_LIB_CONSOLE)
#include <lib/console.h>

static int fletch_runner(int argc, const cmd_args *argv)
{
    unsigned char* snapshot;
    int length  = read_snapshot(&snapshot);
    run_snapshot(snapshot, length);

    return 0;
}

STATIC_COMMAND_START
{ "fletch", "fletch vm", &fletch_runner },
STATIC_COMMAND_END(fletchrunner);
#endif

APP_START(fletchrunner)
.flags = APP_FLAG_CUSTOM_STACK_SIZE,
.stack_size = 8192,
APP_END

