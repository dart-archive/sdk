// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_STATIC_FFI_H_
#define INCLUDE_STATIC_FFI_H_

#include "include/fletch_api.h"

/**
 * The static FFI interface of fletch can be used in two ways. The easiest way
 * is to define an export table that covers all functions that should be
 * available via FFI. This is done using the FLETCH_EXPORT_TABLE macros
 * defined below.
 *
 * FLETCH_EXPORT_TABLE_BEGIN
 *   FLETCH_EXPORT_TABLE_ENTRY("magic_meat", FFITestMagicMeat)
 *   FLETCH_EXPORT_TABLE_ENTRY("magic_veg", FFITestMagicVeg)
 * FLETCH_EXPORT_TABLE_END
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
 *  fletch_ffi_table = .;
 *  KEEP(*(.fletchffi))
 *  QUAD(0)
 *  QUAD(0)
 *  . = ALIGN(4);
 *
 * and export all external functions you want to call via FFI using the below
 * two macros:
 *
 * FLETCH_EXPORT_STATIC(fun) exports the C function 'fun' as 'fun' in dart.
 *
 * FLETCH_EXPORT_STATIC_RENAME(name, fun) exports the C function 'fun' as
 *     'name' in dart.
 */

typedef struct {
  const char* const name;
  const void* const ptr;
} FletchStaticFFISymbol;

#ifdef __cplusplus
#define FLETCH_EXPORT_TABLE_BEGIN \
  extern "C" { \
  FLETCH_VISIBILITY_DEFAULT FletchStaticFFISymbol fletch_ffi_table[] = {
#define FLETCH_EXPORT_TABLE_ENTRY(name, fun) \
  {name, reinterpret_cast<const void*>(&fun)},
#define FLETCH_EXPORT_TABLE_END {NULL, NULL}};}
#else
#define FLETCH_EXPORT_TABLE_BEGIN \
  FLETCH_VISIBILITY_DEFAULT FletchStaticFFISymbol fletch_ffi_table[] = {
#define FLETCH_EXPORT_TABLE_ENTRY(name, fun) {name, &fun},
#define FLETCH_EXPORT_TABLE_END {NULL, NULL}};
#endif

#define FLETCH_FUNCTION_NAME(name) #name
#define FLETCH_EXPORT_FFI FLETCH_EXPORT __attribute__((section(".fletchffi")))

#define FLETCH_EXPORT_STATIC(fun)                                       \
  FLETCH_EXPORT_FFI FletchStaticFFISymbol fletch_ffi_entry_ ## fun = {  \
      FLETCH_FUNCTION_NAME(fun),                                        \
      &fun };                                                           \

#define FLETCH_EXPORT_STATIC_RENAME(name, fun)                           \
  FLETCH_EXPORT_FFI FletchStaticFFISymbol fletch_ffi_entry_ ## name = {  \
      #name, &fun };                                                     \

#endif  // INCLUDE_STATIC_FFI_H_
