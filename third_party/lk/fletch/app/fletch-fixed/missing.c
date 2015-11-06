// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// This file contains all the missing pieces that LK should implement soon
// but currently does not.

#include <stdio.h>

// LK currently lacks an implementation for abort.
void abort(void) {
  printf("Aborted (c-call).\n");
  while (1) {}
}

// Guard implementation from libcxx. See
//   http://llvm.org/svn/llvm-project/libcxxabi/trunk/src/cxa_guard.cpp

// A 32-bit, 4-byte-aligned static data value. The least significant 2 bits must
// be statically initialized to 0.
typedef unsigned guard_type;

int __cxa_guard_acquire(guard_type* guard_object) {
  return !((*guard_object) & 1);
}

void __cxa_guard_release(guard_type* guard_object) {
  *guard_object = 0x1;
}

void __cxa_guard_abort(guard_type* guard_object) {
  *guard_object = 0;
}

// signbit implementation form FreeBSD //

/*-
 * Copyright (c) 2002, 2003 David Schultz <das@FreeBSD.ORG>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

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

