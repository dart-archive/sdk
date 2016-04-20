// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_STATIC_FFI_H_
#define INCLUDE_STATIC_FFI_H_

#include "include/dartino_api.h"

/**
 * The static FFI interface of dartino can be used in two ways. The easiest way
 * is to define an export table that covers all functions that should be
 * available via FFI. This is done using the DARTINO_EXPORT_TABLE macros
 * defined below.
 *
 * DARTINO_EXPORT_TABLE_BEGIN
 *   DARTINO_EXPORT_TABLE_ENTRY("magic_meat", FFITestMagicMeat)
 *   DARTINO_EXPORT_TABLE_ENTRY("magic_veg", FFITestMagicVeg)
 * DARTINO_EXPORT_TABLE_END
 *
 * While easy to integrate into an existing build, this solution does not
 * compose well. All exported functions have to be declared in a single
 * location.
 *
 * Alternatively, a linker script can be used to collect the exported
 * functions from various files. For this, you have to add the following to
 * the output declaration of the rodata section in your linker script
 *
 *  . = ALIGN(4);
 *  dartino_ffi_table = .;
 *  KEEP(*(.dartinoffi))
 *  QUAD(0)
 *  QUAD(0)
 *  . = ALIGN(4);
 *
 * and export all external functions you want to call via FFI using the below
 * two macros:
 *
 * DARTINO_EXPORT_STATIC(fun) exports the C function 'fun' as 'fun' in dart.
 *
 * DARTINO_EXPORT_STATIC_RENAME(name, fun) exports the C function 'fun' as
 *     'name' in dart.
 */

typedef struct {
  const char* const name;
  const void* const ptr;
} DartinoStaticFFISymbol;

#ifdef __cplusplus
#define DARTINO_EXPORT_CAST(fun) (reinterpret_cast<const void*>(fun))
#else
#define DARTINO_EXPORT_CAST(fun) ((const void*)(fun))
#endif  // __cplusplus

#define DARTINO_EXPORT_TABLE_BEGIN \
  DARTINO_VISIBILITY_DEFAULT DartinoStaticFFISymbol dartino_ffi_table[] = {
#define DARTINO_EXPORT_TABLE_ENTRY(name, fun)                                  \
  { name, DARTINO_EXPORT_CAST(&fun)},

#define DARTINO_EXPORT_TABLE_END {NULL, NULL}};

#define DARTINO_FUNCTION_NAME(name) #name
#define DARTINO_EXPORT_FFI __attribute__((section(".dartinoffi")))

#define DARTINO_EXPORT_STATIC(fun)                                             \
  DARTINO_EXPORT_FFI DartinoStaticFFISymbol dartino_ffi_entry_ ## fun = {      \
      DARTINO_FUNCTION_NAME(fun),                                              \
      DARTINO_EXPORT_CAST(&fun) };                                             \

#define DARTINO_EXPORT_STATIC_RENAME(name, fun)                                \
  DARTINO_EXPORT_FFI DartinoStaticFFISymbol dartino_ffi_entry_ ## name = {     \
    #name, DARTINO_EXPORT_CAST(&fun) };

#endif  // INCLUDE_STATIC_FFI_H_
