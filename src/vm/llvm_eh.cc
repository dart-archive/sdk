// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/llvm_eh.h"
#include "src/vm/object.h"
#include "src/vm/process.h"
#include "llvm/Support/Dwarf.h"

extern "C" {

const uint8* _Unwind_GetLanguageSpecificData(_Unwind_Context_t c);
uintptr_t _Unwind_GetGR(_Unwind_Context_t c, int i);
void _Unwind_SetGR(_Unwind_Context_t c, int i, uintptr_t n);
void _Unwind_SetIP(_Unwind_Context_t, uintptr_t new_value);
uintptr_t _Unwind_GetIP(_Unwind_Context_t context);
uintptr_t _Unwind_GetRegionStart(_Unwind_Context_t context);
_Unwind_Reason_Code _Unwind_RaiseException(_Unwind_Exception* exception);

}  // extern "C"

namespace dartino {

// Exception class identification, 2 0-terminated strings in 64bit word.
unsigned char dart_exception_class_chars[] = "GOO\0DRT\0";
uintptr_t dart_exception_class;

void Trace(const char* msg) {
#if 0
  fprintf(stderr, "%s", msg);
#endif
}

// Deletes allocated exception via Unwind_Exception pointer
void DeleteException(_Unwind_Exception* ex) {
  Trace("Delete exception\n");
  if (ex && ex->exception_class == dart_exception_class) {
    delete ex;
  }
}

// The callback to be called by unwinder in order to clean up foreign exceptions
// http://mentorembedded.github.com/cxx-abi/abi-eh.html
void DeleteFromUnwindException(_Unwind_Reason_Code reason,
                               _Unwind_Exception* ex) {
  Trace("Delete exception from unwind\n");
  DeleteException(ex);
}

_Unwind_Exception* CreateException() {
  _Unwind_Exception* ret = new _Unwind_Exception;
  ret->exception_class = dart_exception_class;
  ret->exception_cleanup = DeleteFromUnwindException;
  return ret;
}

// This is part of Dartino run-time, avoid mangling.
extern "C" void ThrowException(Process* process, Object* ex) {
  _Unwind_Exception* e = CreateException();
  process->set_in_flight_exception(ex);
  auto ret = _Unwind_RaiseException(e);
  if (ret == _URC_END_OF_STACK) {
    if (ex->IsSmi()) {
      fprintf(stderr, "Uncaught exception: %d.\n", Smi::cast(ex)->value());
    } else {
      fprintf(stderr, "Uncaught exception.\n");
    }
    exit(255);
  }
  ASSERT(false);
}

// ditto
extern "C" Object* CurrentException(Process* process) {
  return process->in_flight_exception();
}

/// Read a unsigned leb128 encoded value
/// See 7.6 Variable Length Data
/// http://dwarfstd.org/doc/Dwarf3.pdf
static uintptr_t ReadULEB128(const uint8** data) {
  uintptr_t result = 0;
  uintptr_t shift = 0;
  const uint8* p = *data;
  uint8 b;
  do {
    b = *p;
    result |= (b & 0x7f) << shift;
    shift += 7;
    p++;
  } while (b & 0x80);
  *data = p;
  return result;
}

/// Read a signed leb128 encoded value
/// See 7.6 Variable Length Data
/// http://dwarfstd.org/doc/Dwarf3.pdf
static uintptr_t ReadSLEB128(const uint8** data) {
  uintptr_t result = 0;
  uintptr_t shift = 0;
  const uint8* p = *data;
  uint8 b;
  do {
    b = *p;
    result |= (b & 0x7f) << shift;
    shift += 7;
    p++;
  } while (b & 0x80);
  // Sign extend.
  if ((b & 0x40) && shift < sizeof(result) * 8) {
    result |= ~0 << shift;
  }
  *data = p;
  return result;
}

/// Read a pointer encoded value
/// See 7.6 Variable Length Data
/// http://dwarfstd.org/doc/Dwarf3.pdf
static uintptr_t ReadDwarfPointer(const uint8** data, uint8 encoding) {
  uintptr_t result = 0;
  const uint8* p = *data;

  if (encoding == llvm::dwarf::DW_EH_PE_omit) {
    return result;
  }

  // Get the value.
  switch (encoding & 0x0f) {
    case llvm::dwarf::DW_EH_PE_absptr:
      result = *reinterpret_cast<const uintptr_t*>(p);
      p += sizeof(uintptr_t);
      break;
    case llvm::dwarf::DW_EH_PE_uleb128:
      result = ReadULEB128(&p);
      break;
    case llvm::dwarf::DW_EH_PE_sleb128:
      result = ReadSLEB128(&p);
      break;
    case llvm::dwarf::DW_EH_PE_udata2:
      result = *reinterpret_cast<const uint16_t*>(p);
      p += sizeof(uint16_t);
      break;
    case llvm::dwarf::DW_EH_PE_udata4:
      result = *reinterpret_cast<const uint32_t*>(p);
      p += sizeof(uint32_t);
      break;
    case llvm::dwarf::DW_EH_PE_udata8:
      result = *reinterpret_cast<const uint64_t*>(p);
      p += sizeof(uint64_t);
      break;
    case llvm::dwarf::DW_EH_PE_sdata2:
      result = *reinterpret_cast<const int16_t*>(p);
      p += sizeof(int16_t);
      break;
    case llvm::dwarf::DW_EH_PE_sdata4:
      result = *reinterpret_cast<const int32_t*>(p);
      p += sizeof(int32_t);
      break;
    case llvm::dwarf::DW_EH_PE_sdata8:
      result = *reinterpret_cast<const int64_t*>(p);
      p += sizeof(int64_t);
      break;
    default:
      UNREACHABLE();
  }
  // Then add relative offset.
  switch (encoding & 0x70) {
    case llvm::dwarf::DW_EH_PE_absptr:
      // NOP
      break;
    case llvm::dwarf::DW_EH_PE_pcrel:
      result += reinterpret_cast<uintptr_t>(*data);
      break;
    case llvm::dwarf::DW_EH_PE_textrel:
    case llvm::dwarf::DW_EH_PE_datarel:
    case llvm::dwarf::DW_EH_PE_funcrel:
    case llvm::dwarf::DW_EH_PE_aligned:
    default:
      UNREACHABLE();
  }
  // Apply indirection if needed.
  if (encoding & llvm::dwarf::DW_EH_PE_indirect) {
    result = *reinterpret_cast<const uintptr_t*>(result);
  }
  *data = p;
  return result;
}

// This is the personality function which is embedded in the
// dwarf unwind info block.
extern "C" _Unwind_Reason_Code DartPersonality(int version,
                                               _Unwind_Action actions,
                                               uint64_t exceptionClass,
                                               _Unwind_Exception* exception,
                                               _Unwind_Context_t context) {
  if (actions & _UA_SEARCH_PHASE) {
    Trace("DartPersonality: in search phase.\n");
  } else {
    Trace("DartPersonality: in non-search phase.\n");
  }
  const uint8* lsda = _Unwind_GetLanguageSpecificData(context);
  _Unwind_Reason_Code ret = _URC_CONTINUE_UNWIND;
  if (!lsda) return ret;
  // Get the current instruction pointer and offset it before the next
  // instruction in the current frame which threw the exception.
  uintptr_t pc = _Unwind_GetIP(context) - 1;

  // Get beginning current frame's code pointer.
  uintptr_t func_start = _Unwind_GetRegionStart(context);
  uintptr_t pc_offset = pc - func_start;

  // Parse LSDA header.
  uint8 start_encoding = *lsda++;

  if (start_encoding != llvm::dwarf::DW_EH_PE_omit) {
    ReadDwarfPointer(&lsda, start_encoding);
  }

  uint8 type_encoding = *lsda++;

  if (type_encoding != llvm::dwarf::DW_EH_PE_omit) {
    ReadULEB128(&lsda);
  }

  // Walk call-site table looking for a range that
  // includes the current PC.
  uint8 call_site_encoding = *lsda++;
  uint32_t call_site_table_length = ReadULEB128(&lsda);
  const uint8* call_site_table_start = lsda;
  const uint8* call_site_table_end =
      call_site_table_start + call_site_table_length;
  const uint8* call_site_ptr = call_site_table_start;

  while (call_site_ptr < call_site_table_end) {
    uintptr_t start = ReadDwarfPointer(&call_site_ptr, call_site_encoding);
    uintptr_t length = ReadDwarfPointer(&call_site_ptr, call_site_encoding);
    uintptr_t landing_pad =
        ReadDwarfPointer(&call_site_ptr, call_site_encoding);
    ReadULEB128(&call_site_ptr);  // Skip action entry.

    if (landing_pad == 0) {
      Trace("DartPersonality: no landing pad found.\n");
      continue;  // No landing pad for this entry.
    }

    if (pc_offset >= start && pc_offset < start + length) {
      Trace("DartPersonality: landing pad found.\n");
      if (!(actions & _UA_SEARCH_PHASE)) {
        Trace("DartPersonality: installing landing pad context.\n");
        // To execute landing pad set here.
        _Unwind_SetIP(context, func_start + landing_pad);
        ret = _URC_INSTALL_CONTEXT;
      } else {
        Trace("DartPersonality: handler found.\n");
        ret = _URC_HANDLER_FOUND;
      }
      break;
    }
  }

  return ret;
}

// Generate uint64 class identifier from character string.
uint64_t GenClass(unsigned char* class_chars, size_t size) {
  uint64_t ret = class_chars[0];
  for (size_t i = 1; i < size; i++) {
    ret = (ret << 8) | class_chars[i];
  }
  return ret;
}

void ExceptionsSetup() {
  dart_exception_class = GenClass(dart_exception_class_chars, 8);
}

}  // namespace dartino
