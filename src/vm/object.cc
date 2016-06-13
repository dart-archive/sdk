// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/object.h"

#include <stdio.h>
#include <stdlib.h>

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"

#include "src/vm/frame.h"
#include "src/vm/intrinsics.h"
#include "src/vm/natives.h"
#include "src/vm/process.h"
#include "src/vm/program.h"
#include "src/vm/unicode.h"

namespace dartino {

uword StaticClassStructures::meta_class_storage[Class::kSize / sizeof(uword)];
uword StaticClassStructures::free_list_chunk_class_storage[Class::kSize
    / sizeof(uword)];
uword StaticClassStructures::one_word_filler_class_storage[Class::kSize
    / sizeof(uword)];
uword StaticClassStructures::promoted_track_class_storage[Class::kSize
    / sizeof(uword)];

static void CopyBlock(Object** dst, Object** src, int byte_size) {
  ASSERT(byte_size > 0);
  ASSERT(Utils::IsAligned(byte_size, kPointerSize));

  // Use block copying memcpy if the segment we're copying is
  // enough to justify the extra call/setup overhead.
  static const int kBlockCopyLimit = 16 * kPointerSize;

  if (byte_size >= kBlockCopyLimit) {
    memcpy(dst, src, byte_size);
  } else {
    int remaining = byte_size / kPointerSize;
    do {
      remaining--;
      *dst++ = *src++;
    } while (remaining > 0);
  }
}

uword HeapObject::Size() {
  // Fast check for non-variable length types.
  ASSERT(!HasForwardingAddress());
  InstanceFormat format = raw_class()->instance_format();
  if (!format.has_variable_part()) return format.fixed_size();
  int type = format.type();
  switch (type) {
    case InstanceFormat::ONE_BYTE_STRING_TYPE:
      return OneByteString::cast(this)->StringSize();
    case InstanceFormat::TWO_BYTE_STRING_TYPE:
      return TwoByteString::cast(this)->StringSize();
    case InstanceFormat::ARRAY_TYPE:
      return Array::cast(this)->ArraySize();
    case InstanceFormat::BYTE_ARRAY_TYPE:
      return ByteArray::cast(this)->ByteArraySize();
    case InstanceFormat::FUNCTION_TYPE:
      return Function::cast(this)->FunctionSize();
    case InstanceFormat::STACK_TYPE:
      return Stack::cast(this)->StackSize();
    case InstanceFormat::DOUBLE_TYPE:
      return Double::cast(this)->DoubleSize();
    case InstanceFormat::LARGE_INTEGER_TYPE:
      return LargeInteger::cast(this)->LargeIntegerSize();
    case InstanceFormat::DISPATCH_TABLE_ENTRY_TYPE:
      return DispatchTableEntry::cast(this)->DispatchTableEntrySize();
    case InstanceFormat::FREE_LIST_CHUNK_TYPE:
      return FreeListChunk::cast(this)->size();
    case InstanceFormat::PROMOTED_TRACK_TYPE:
      return PromotedTrack::cast(this)->size();
  }
  UNREACHABLE();
  return 0;
}

uword HeapObject::FixedSize() {
  // Fast check for non variable length types.
  ASSERT(!HasForwardingAddress());
  InstanceFormat format = raw_class()->instance_format();
  return format.fixed_size();
}

bool OneByteString::Equals(List<const uint8> str) {
  int us = str.length();
  if (length() != us) return false;
  for (int i = 0; i < us; i++) {
    if (get_char_code(i) != str[i]) return false;
  }
  return true;
}

bool OneByteString::Equals(OneByteString* str) {
  if (this == str) return true;
  int len = str->length();
  if (length() != len) return false;
  for (int i = 0; i < len; i++) {
    if (get_char_code(i) != str->get_char_code(i)) return false;
  }
  return true;
}

bool OneByteString::Equals(TwoByteString* str) {
  int len = str->length();
  if (length() != len) return false;
  for (int i = 0; i < len; i++) {
    if (get_char_code(i) != str->get_code_unit(i)) return false;
  }
  return true;
}

bool TwoByteString::Equals(List<const uint16_t> str) {
  int us = str.length();
  if (length() != us) return false;
  for (int i = 0; i < us; i++) {
    if (get_code_unit(i) != str[i]) return false;
  }
  return true;
}

bool TwoByteString::Equals(TwoByteString* str) {
  if (this == str) return true;
  int len = str->length();
  if (length() != len) return false;
  for (int i = 0; i < len; i++) {
    if (get_code_unit(i) != str->get_code_unit(i)) return false;
  }
  return true;
}

void Function::Initialize(List<uint8> bytecodes) {
  set_bytecode_size(bytecodes.length());
  uint8* bytecodes_address = bytecode_address_for(0);
  memcpy(bytecodes_address, bytecodes.data(), bytecodes.length());
}

Function* Function::FromBytecodePointer(uint8* bcp, int* frame_ranges_offset) {
  while (*bcp != kMethodEnd) {
    bcp += Bytecode::Size(static_cast<Opcode>(*bcp));
  }
  // Read value.
  int value = Utils::ReadInt32(bcp + 1);
  int delta = value >> 1;
  if (frame_ranges_offset != NULL) {
    if ((value & 1) == 1) {
      *frame_ranges_offset = delta + kMethodEndLength;
    } else {
      *frame_ranges_offset = -1;
    }
  }
  uword address = reinterpret_cast<uword>(bcp - delta - kSize);
  return Function::cast(HeapObject::FromAddress(address));
}

void* Function::ComputeIntrinsic(IntrinsicsTable* table) {
  int length = bytecode_size();
  uint8* bytecodes = bytecode_address_for(0);
  void* result = NULL;
  if (length >= 4 && bytecodes[0] == kLoadLocal3 &&
      bytecodes[1] == kLoadField && bytecodes[3] == kReturn) {
    result = reinterpret_cast<void*>(table->GetField());
  } else if (length >= 4 && bytecodes[0] == kLoadLocal4 &&
             bytecodes[1] == kLoadLocal4 &&
             bytecodes[2] == kIdenticalNonNumeric && bytecodes[3] == kReturn) {
    // TODO(ajohnsen): Investigate what pattern we generate for this now.
    UNIMPLEMENTED();
  } else if (length >= 5 && bytecodes[0] == kLoadLocal4 &&
             bytecodes[1] == kLoadLocal4 && bytecodes[2] == kStoreField &&
             bytecodes[4] == kReturn) {
    result = reinterpret_cast<void*>(table->SetField());
  } else if (length >= 3 && bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListIndexGet) {
    result = reinterpret_cast<void*>(table->ListIndexGet());
  } else if (length >= 3 && bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListIndexSet) {
    result = reinterpret_cast<void*>(table->ListIndexSet());
  } else if (length >= 3 && bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListLength) {
    result = reinterpret_cast<void*>(table->ListLength());
  }
  return result;
}

void Object::Print() {
  if (IsSmi()) {
    Smi::cast(this)->SmiPrint();
  } else {
    HeapObject::cast(this)->HeapObjectPrint();
  }
  Print::Out("\n");
}

void Object::ShortPrint() {
  if (IsSmi()) {
    Smi::cast(this)->SmiPrint();
  } else {
    HeapObject::cast(this)->HeapObjectShortPrint();
  }
}

void Smi::SmiPrint() { Print::Out("%ld", value()); }

void OneByteString::FillFrom(OneByteString* x, int offset) {
  int xlen = x->length();
  ASSERT(offset + xlen <= length());
  memcpy(byte_address_for(offset), x->byte_address_for(0), xlen);
}

void OneByteString::OneByteStringPrint() {
  RawPrint("OneByteString");
  Print::Out("\"");
  OneByteStringShortPrint();
  Print::Out("\"");
}

void OneByteString::OneByteStringShortPrint() {
  char* result = ToCString();
  Print::Out("%s", result);
  free(result);
}

char* OneByteString::ToCString() {
  intptr_t len = 0;
  for (int i = 0; i < length(); i++) {
    len += Utf8::Length(get_char_code(i));
  }
  char* result = reinterpret_cast<char*>(malloc(len + 1));
  char* buffer = result;
  for (int i = 0; i < length(); i++) {
    buffer += Utf8::Encode(get_char_code(i), buffer);
  }
  result[len] = 0;
  return result;
}

void TwoByteString::FillFrom(OneByteString* x, int offset) {
  int xlen = x->length();
  ASSERT(offset + xlen <= length());
  for (int i = 0; i < xlen; i++) {
    set_code_unit(offset + i, x->get_char_code(i));
  }
}

void TwoByteString::FillFrom(TwoByteString* x, int offset) {
  int xlen = x->length();
  ASSERT(offset + xlen <= length());
  memcpy(byte_address_for(offset), x->byte_address_for(0),
         xlen * sizeof(uint16));
}

void TwoByteString::TwoByteStringPrint() {
  RawPrint("TwoByteString");
  Print::Out("\"");
  TwoByteStringShortPrint();
  Print::Out("\"");
}

void TwoByteString::TwoByteStringShortPrint() {
  char* result = ToCString();
  Print::Out("%s", result);
  free(result);
}

char* TwoByteString::ToCString() {
  intptr_t len = Utf8::Length(this);
  char* result = reinterpret_cast<char*>(malloc(len + 1));
  Utf8::Encode(this, result, len);
  result[len] = 0;
  return result;
}

Instance* Instance::CloneTransformed(Heap* heap) {
  ASSERT(!HasForwardingAddress());
  Class* old_class = get_class();
  Class* new_class = old_class->TransformationTarget();
  Array* transformation = old_class->Transformation();

  // NOTE: We do not pass 'immmutable = get_immutable()' here, since the
  // immutability bit and the identity hascode will get copied via the flags
  // word.
  Object* clone = heap->CreateInstance(new_class, Smi::FromWord(0), false);
  if (clone->IsRetryAfterGCFailure()) {
    // We can only get an allocation failure on the new-space in a two-space
    // heap, since there is a NoAllocationFailureScope on the program heap
    // and on the old generation of the process heap.
    ASSERT(!heap->IsTwoSpaceHeap());
    TwoSpaceHeap* tsh = reinterpret_cast<TwoSpaceHeap*>(heap);
    clone = tsh->CreateOldSpaceInstance(new_class, Smi::FromWord(0));
    ASSERT(!clone->IsFailure());
  }
  Instance* target = Instance::cast(clone);

  // Copy the flags word from the old instance.
  target->SetFlagsBits(FlagsBits());

  int old_fields = old_class->NumberOfInstanceFields();
  int new_fields = new_class->NumberOfInstanceFields();

  int new_prefix = transformation->length() / 2;
  int old_prefix = new_prefix - (new_fields - old_fields);
  int suffix = new_fields - new_prefix;

  Object** new_fields_pointer =
      reinterpret_cast<Object**>(target->address() + Instance::kSize);
  Object** old_fields_pointer =
      reinterpret_cast<Object**>(address() + Instance::kSize);

  // Transform the prefix.
  for (int i = 0; i < new_prefix; i++) {
    int tag = Smi::cast(transformation->get(i * 2 + 0))->value();
    Object* value = transformation->get(i * 2 + 1);
    if (tag == 0) {
      new_fields_pointer[i] = value;
    } else {
      ASSERT(tag == 1);
      int index = Smi::cast(value)->value();
      ASSERT(index >= 0 && index < old_fields);
      new_fields_pointer[i] = old_fields_pointer[index];
    }
  }

  // Copy the suffix over if it is non-empty.
  if (suffix > 0) {
    CopyBlock(new_fields_pointer + new_prefix, old_fields_pointer + old_prefix,
              suffix * sizeof(Object*));
  }

  // Zap old fields with fillers. This makes it possible to iterate the
  // fields part of the transformed instance.
  for (int i = 0; i < old_fields; i++) {
    *(old_fields_pointer + i) = StaticClassStructures::one_word_filler_class();
  }

  return target;
}

void Instance::InstancePrint() {
  RawPrint("Instance");
  Print::Out("\n");
  Print::Out("  - class = ");
  get_class()->ShortPrint();
  Print::Out("\n");
  int fields = get_class()->NumberOfInstanceFields();
  for (int i = 0; i < fields; i++) {
    Print::Out("  - @%d = ", i);
    GetInstanceField(i)->ShortPrint();
    Print::Out("\n");
  }
}

void Instance::InstanceShortPrint() {
  if (IsNull()) {
    Print::Out("null");
  } else {
    Class* clazz = get_class();
    Print::Out("instance of ");
    clazz->ShortPrint();
  }
}

void Array::ArrayPrint() {
  RawPrint("Array");
  Print::Out("\n");
  Print::Out("  - length = %d\n", length());
  int len = length();
  for (int i = 0; i < len; i++) {
    Print::Out("  - [%d] = ", i);
    get(i)->ShortPrint();
    Print::Out("\n");
  }
}

void Array::ArrayShortPrint() {
  Print::Out("[");
  int len = length();
  for (int i = 0; i < len; i++) {
    get(i)->ShortPrint();
    if (i + 1 < len) Print::Out(", ");
  }
  Print::Out("]");
}

void ByteArray::ByteArrayPrint() {
  RawPrint("ByteArray");
  Print::Out("\n");
  Print::Out("  - length = %d\n", length());
  int len = length();
  for (int i = 0; i < len; i++) {
    Print::Out("  - [%d] = %d\n", i, get(i));
  }
}

void ByteArray::ByteArrayShortPrint() {
  Print::Out("[");
  int len = length();
  for (int i = 0; i < len; i++) {
    Print::Out("%d", get(i));
    if (i + 1 < len) Print::Out(", ");
  }
  Print::Out("]");
}

void Function::FunctionPrint() {
  RawPrint("Function");
  Print::Out("\n");
  Print::Out("  - bytecode_size = %d\n", bytecode_size());
}

void Function::FunctionShortPrint() {
  Print::Out("function #%d", bytecode_size());
}

void LargeInteger::LargeIntegerPrint() {
  Print::Out("- large integer: ");
  LargeIntegerShortPrint();
  Print::Out("\n");
}

void LargeInteger::LargeIntegerShortPrint() {
  Print::Out("%lld", static_cast<long long int>(value()));  // NOLINT
}

void Double::DoublePrint() {
  Print::Out("- double: ");
  DoubleShortPrint();
  Print::Out("\n");
}

void Double::DoubleShortPrint() { Print::Out("%f", value()); }

void Boxed::BoxedPrint() {
  Print::Out("- boxed: ");
  BoxedShortPrint();
  Print::Out("\n");
}

void Boxed::BoxedShortPrint() { value()->ShortPrint(); }

void Initializer::InitializerPrint() {
  Print::Out("- initializer: ");
  Print::Out("initializer: ");
  function()->Print();
  Print::Out("\n");
}

void Initializer::InitializerShortPrint() {
  Print::Out("initializer ");
  function()->ShortPrint();
  Print::Out("\n");
}

void Class::Transform(Class* target, Array* transformation) {
  ASSERT(!IsTransformed());
  at_put(kIdOrTransformationTargetOffset, target);
  at_put(kChildIdOrTransformationOffset, transformation);
  ASSERT(IsTransformed());
}

Function* Class::LookupMethod(int selector) {
  ASSERT(Smi::IsValid(selector));
  Smi* selector_smi = Smi::FromWord(selector);
  Class* current = this;
  while (true) {
    Array* methods = current->methods();
    ASSERT(methods->length() % 2 == 0);
    if (methods->length() > 0) {
      int first = 0;
      int last = (methods->length() / 2) - 1;
      while (first <= last) {
        int middle = (first + last) / 2;
        Smi* current = Smi::cast(methods->get(middle * 2));
        if (current == selector_smi) {
          return Function::cast(methods->get(middle * 2 + 1));
        }
        if (current > selector_smi) {
          last = middle - 1;
        } else {
          first = middle + 1;
        }
      }
    }
    if (!current->has_super_class()) return NULL;
    current = current->super_class();
  }
}

bool Class::IsSubclassOf(Class* klass) {
  Class* current = this;
  while (current != klass) {
    if (!current->has_super_class()) return false;
    current = current->super_class();
  }
  return true;
}

void Class::ClassPrint() {
  RawPrint("Class");
  Print::Out("\n");
  Print::Out("\n");
  if (instance_format().type() == InstanceFormat::INSTANCE_TYPE) {
    Print::Out("  - number of instance fields = %d\n",
               NumberOfInstanceFields());
  }
  uword size = instance_format().fixed_size();
  Print::Out("  - instance object size = %d\n", size);
  Print::Out("  - methods = ");
  methods()->ShortPrint();
  Print::Out("\n");
}

void Class::ClassShortPrint() { Print::Out("class"); }

void ByteArray::IterateEverything(PointerVisitor* visitor) {
  visitor->VisitInteger(address() + BaseArray::kLengthOffset);
  ByteArray* byte_array = ByteArray::cast(this);
  if (byte_array->length() != 0) {
    visitor->VisitRaw(byte_array->byte_address_for(0), byte_array->length());
  }
}

void OneByteString::IterateEverything(PointerVisitor* visitor) {
  visitor->VisitInteger(address() + BaseArray::kLengthOffset);
  visitor->VisitInteger(address() + OneByteString::kHashValueOffset);
  OneByteString* str = OneByteString::cast(this);
  visitor->VisitRaw(str->byte_address_for(0), str->length());
}

void TwoByteString::IterateEverything(PointerVisitor* visitor) {
  visitor->VisitInteger(address() + BaseArray::kLengthOffset);
  visitor->VisitInteger(address() + TwoByteString::kHashValueOffset);
  TwoByteString* str = TwoByteString::cast(this);
  visitor->VisitRaw(str->byte_address_for(0), str->length() * 2);
}

void Array::IterateEverything(PointerVisitor* visitor) {
  visitor->VisitInteger(address() + BaseArray::kLengthOffset);
  Array* array = reinterpret_cast<Array*>(this);
  visitor->VisitBlock(
      reinterpret_cast<Object**>(address() + (2 * kPointerSize)),
      reinterpret_cast<Object**>(address() + array->ArraySize()));
}

void Function::IterateEverything(PointerVisitor* visitor) {
  visitor->VisitInteger(address() + Function::kBytecodeSizeOffset);
  visitor->VisitInteger(address() + Function::kLiteralsSizeOffset);
  visitor->VisitInteger(address() + Function::kArityOffset);
  Function* function = reinterpret_cast<Function*>(this);
  visitor->VisitByteCodes(function->bytecode_address_for(0),
                          function->bytecode_size());
  Object** first = function->literal_address_for(0);
  visitor->VisitBlock(first, first + function->literals_size());
}

void DispatchTableEntry::IterateEverything(PointerVisitor* visitor) {
  visitor->Visit(reinterpret_cast<Object**>(address() +
                                            DispatchTableEntry::kTargetOffset));
  visitor->VisitCode(address() + DispatchTableEntry::kCodeOffset);
  visitor->VisitInteger(address() + DispatchTableEntry::kOffsetOffset);
  visitor->VisitInteger(address() + DispatchTableEntry::kSelectorOffset);
}

void Instance::IterateEverything(PointerVisitor* visitor) {
  int32 flags = *reinterpret_cast<int32*>(address() + Instance::kFlagsOffset);
  visitor->VisitLiteralInteger(flags);
  visitor->VisitBlock(reinterpret_cast<Object**>(address() + Instance::kSize),
                      reinterpret_cast<Object**>(address() + Size()));
}

void Class::IterateEverything(PointerVisitor* visitor) {
  visitor->Visit(
      reinterpret_cast<Object**>(address() + Class::kSuperClassOffset));
  visitor->VisitInteger(address() + Class::kInstanceFormatOffset);
  visitor->VisitInteger(address() + Class::kIdOrTransformationTargetOffset);
  visitor->Visit(reinterpret_cast<Object**>(
      address() + Class::kChildIdOrTransformationOffset));
  visitor->Visit(reinterpret_cast<Object**>(address() + Class::kMethodsOffset));
}

void Boxed::IterateEverything(PointerVisitor* visitor) {
  visitor->Visit(reinterpret_cast<Object**>(address() + Boxed::kValueOffset));
}

void Initializer::IterateEverything(PointerVisitor* visitor) {
  visitor->Visit(
      reinterpret_cast<Object**>(address() + Initializer::kFunctionOffset));
}

void Double::IterateEverything(PointerVisitor* visitor) {
  Double* floating = Double::cast(this);
  visitor->VisitFloat(floating->value());
}

void LargeInteger::IterateEverything(PointerVisitor* visitor) {
  visitor->VisitRaw(reinterpret_cast<uint8*>(address() + kWordSize),
                    sizeof(int64));
}

// Only used by the serializer. Unlike IteratePointers, this cares about all
// of the object, not just pointers. Eg it cares about integer fields,
// always-Smi fields and pointers to machine code outside the heap.
void HeapObject::IterateEverything(PointerVisitor* visitor) {
  visitor->VisitClass(reinterpret_cast<Object**>(address()));

  InstanceFormat format = get_class()->instance_format();

  switch (format.type()) {
    case InstanceFormat::BYTE_ARRAY_TYPE:
      ByteArray::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::ONE_BYTE_STRING_TYPE:
      OneByteString::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::TWO_BYTE_STRING_TYPE:
      TwoByteString::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::ARRAY_TYPE:
      Array::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::FUNCTION_TYPE:
      Function::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::DISPATCH_TABLE_ENTRY_TYPE:
      DispatchTableEntry::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::INSTANCE_TYPE:
      Instance::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::CLASS_TYPE:
      Class::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::BOXED_TYPE:
      Boxed::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::INITIALIZER_TYPE:
      Initializer::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::DOUBLE_TYPE:
      Double::cast(this)->IterateEverything(visitor);
      return;
    case InstanceFormat::LARGE_INTEGER_TYPE:
      LargeInteger::cast(this)->IterateEverything(visitor);
      return;
    default:
      UNREACHABLE();
  }
}

InstanceFormat HeapObject::IteratePointers(PointerVisitor* visitor) {
  ASSERT(!HasForwardingAddress());

  visitor->VisitClass(reinterpret_cast<Object**>(address()));

  InstanceFormat format = get_class()->instance_format();
  // Fast case for fixed size object with all pointers.
  if (format.only_pointers_in_fixed_part()) {
    uword size = format.fixed_size();
    if (size > kPointerSize) {
      visitor->VisitBlock(reinterpret_cast<Object**>(address() + kPointerSize),
                          reinterpret_cast<Object**>(address() + size));
    }
    return format;
  }
  switch (format.type()) {
    case InstanceFormat::ARRAY_TYPE: {
      // We do not use cast method because the Array's class pointer is not
      // valid during marking.
      Array* array = reinterpret_cast<Array*>(this);
      visitor->VisitBlock(
          reinterpret_cast<Object**>(address() + (2 * kPointerSize)),
          reinterpret_cast<Object**>(address() + array->ArraySize()));
      break;
    }

    case InstanceFormat::STACK_TYPE: {
      // We do not use cast method because the Stack's class pointer is not
      // valid during marking.
      Stack* stack = reinterpret_cast<Stack*>(this);
      Frame frame(stack);
      visitor->AboutToVisitStack(stack);
      visitor->Visit(stack->address_at(Stack::kNextOffset));
      while (frame.MovePrevious()) {
        visitor->VisitBlock(frame.LastLocalAddress(),
                            frame.FirstLocalAddress() + 1);
      }
      break;
    }

    case InstanceFormat::FUNCTION_TYPE: {
      // We do not use cast method because the Function's class pointer is not
      // valid during marking.
      Function* function = reinterpret_cast<Function*>(this);
      Object** first = function->literal_address_for(0);
      visitor->VisitBlock(first, first + function->literals_size());
      break;
    }

    default:
      UNREACHABLE();
  }
  return format;
}

word HeapObject::forwarding_word() {
  Object* header = at(kClassOffset);
  if (!header->IsSmi()) return 0;
  return reinterpret_cast<word>(header);
}

void HeapObject::set_forwarding_word(word value) {
  ASSERT(forwarding_word() == 0);
  at_put(kClassOffset, Smi::cast(reinterpret_cast<Smi*>(value)));
}

void HeapObject::set_forwarding_address(HeapObject* value) {
  ASSERT(!HasForwardingAddress());
  at_put(kClassOffset, Smi::cast(reinterpret_cast<Smi*>(value->address())));
}

void Stack::UpdateFramePointers(Stack* old_stack) {
  Object** fp = Pointer(top());
  Object** old_fp = old_stack->Pointer(old_stack->top());
  word diff = (fp - old_fp) * kWordSize;
  UpdateFramePointers(diff);
}

void Stack::UpdateFramePointers(word diff) {
  Object** fp = Pointer(top());
  while (*fp != NULL) {
    // Read the fp value and update it.
    Object* fp_value = *fp + diff;
    // Store back the updated value.
    *fp = fp_value;
    // Continue with the updated value as a new fp.
    fp = reinterpret_cast<Object**>(fp_value);
  }
}

// Explicit instantiation of just these two types.
template HeapObject* HeapObject::CloneInToSpace<SemiSpace>(SemiSpace* s);
template HeapObject* HeapObject::CloneInToSpace<OldSpace>(OldSpace* s);

template <class SomeSpace>
HeapObject* HeapObject::CloneInToSpace(SomeSpace* to) {
  ASSERT(!to->Includes(this->address()));
  ASSERT(!HasForwardingAddress());
  // No forwarding address, so copy the object to the 'to' space
  // and insert a forward pointer.
  int object_size = Size();
  uword new_address = to->Allocate(object_size);
  if (new_address == 0) {
    return NULL;
  }
  HeapObject* target = HeapObject::FromAddress(new_address);
  // Copy the content of source to target.
  CopyBlock(reinterpret_cast<Object**>(new_address),
            reinterpret_cast<Object**>(address()), object_size);
  if (target->IsStack()) {
    Stack::cast(target)->UpdateFramePointers(Stack::cast(this));
  }
  // Set the forwarding address.
  set_forwarding_address(target);

  return target;
}

// Helper class for printing HeapObjects
class PrintVisitor : public PointerVisitor {
 public:
  void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) PrintPointer(p);
  }

  void VisitClass(Object** p) {}

 private:
  void PrintPointer(Object** p) {
    Print::Out(" [0x%lx] = ", reinterpret_cast<uword>(p));
    (*p)->ShortPrint();
    Print::Out("\n");
  }
};

void HeapObject::RawPrint(const char* title) {
  if (!Flags::verbose) {
    Print::Out("a %s: ", title);
  } else {
    Print::Out("0x%lx: [%s] (%d): ", address(), title,
               static_cast<int>(Size()));
    PrintVisitor v;
    IteratePointers(&v);
  }
}

void HeapObject::HeapObjectPrint() {
  switch (get_class()->instance_format().type()) {
    case InstanceFormat::CLASS_TYPE:
      Class::cast(this)->ClassPrint();
      break;
    case InstanceFormat::INSTANCE_TYPE:
      Instance::cast(this)->InstancePrint();
      break;
    case InstanceFormat::ONE_BYTE_STRING_TYPE:
      OneByteString::cast(this)->OneByteStringPrint();
      break;
    case InstanceFormat::TWO_BYTE_STRING_TYPE:
      TwoByteString::cast(this)->TwoByteStringPrint();
      break;
    case InstanceFormat::ARRAY_TYPE:
      Array::cast(this)->ArrayPrint();
      break;
    case InstanceFormat::FUNCTION_TYPE:
      Function::cast(this)->FunctionPrint();
      break;
    case InstanceFormat::LARGE_INTEGER_TYPE:
      LargeInteger::cast(this)->LargeIntegerPrint();
      break;
    case InstanceFormat::BYTE_ARRAY_TYPE:
      ByteArray::cast(this)->ByteArrayPrint();
      break;
    case InstanceFormat::DOUBLE_TYPE:
      Double::cast(this)->DoublePrint();
      break;
    case InstanceFormat::INITIALIZER_TYPE:
      Initializer::cast(this)->InitializerPrint();
      break;
    default:
      UNREACHABLE();
  }
}

void HeapObject::HeapObjectShortPrint() {
  switch (get_class()->instance_format().type()) {
    case InstanceFormat::CLASS_TYPE:
      Class::cast(this)->ClassShortPrint();
      break;
    case InstanceFormat::INSTANCE_TYPE:
      Instance::cast(this)->InstanceShortPrint();
      break;
    case InstanceFormat::ONE_BYTE_STRING_TYPE:
      OneByteString::cast(this)->OneByteStringShortPrint();
      break;
    case InstanceFormat::TWO_BYTE_STRING_TYPE:
      TwoByteString::cast(this)->TwoByteStringShortPrint();
      break;
    case InstanceFormat::ARRAY_TYPE:
      Array::cast(this)->ArrayShortPrint();
      break;
    case InstanceFormat::FUNCTION_TYPE:
      Function::cast(this)->FunctionShortPrint();
      break;
    case InstanceFormat::LARGE_INTEGER_TYPE:
      LargeInteger::cast(this)->LargeIntegerShortPrint();
      break;
    case InstanceFormat::BYTE_ARRAY_TYPE:
      ByteArray::cast(this)->ByteArrayShortPrint();
      break;
    case InstanceFormat::DOUBLE_TYPE:
      Double::cast(this)->DoubleShortPrint();
      break;
    case InstanceFormat::INITIALIZER_TYPE:
      Initializer::cast(this)->InitializerShortPrint();
      break;
    default:
      UNREACHABLE();
  }
}

uword CookedHeapObjectPointerVisitor::Visit(HeapObject* object) {
  uword size = object->Size();
  if (object->IsStack()) {
    visitor_->VisitClass(reinterpret_cast<Object**>(object->address()));
    // We make sure to visit one extra slot which is now the function
    // pointer when stacks are cooked.
    Frame frame(reinterpret_cast<Stack*>(object));
    while (frame.MovePrevious()) {
      visitor_->VisitBlock(frame.LastLocalAddress(),
                           frame.FirstLocalAddress() + 2);
    }
  } else {
    object->IteratePointers(visitor_);
  }
  return size;
}

PromotedTrack* PromotedTrack::Initialize(PromotedTrack* next, uword location,
                                         uword end) {
  PromotedTrack* self =
      reinterpret_cast<PromotedTrack*>(HeapObject::FromAddress(location));
  GCMetadata::RecordStart(self->address());
  // We mark the PromotedTrack object as dirty (containing new-space
  // pointers). This is because the remembered-set scanner mainly looks at
  // these dirty-bytes.  It ensures that the remembered-set scanner does not
  // skip past the PromotedTrack object header and start scanning newly
  // allocated objects inside the PromotedTrack area before they are
  // traversable.
  GCMetadata::InsertIntoRememberedSet(self->address());
  self->set_class(StaticClassStructures::promoted_track_class());
  self->set_next(next);
  self->set_end(end);
  return self;
}

#ifdef DEBUG
class ContainsPointerVisitor : public PointerVisitor {
 public:
  ContainsPointerVisitor(Space* space, bool* flag)
      : space_(space), flag_(flag) {}

  virtual void VisitBlock(Object** start, Object** end) {
    for (Object** current = start; current < end; current++) {
      Object* object = *current;
      if (object->IsHeapObject()) {
        HeapObject* heap_object = HeapObject::cast(object);
        if (space_->Includes(heap_object->address())) *flag_ = true;
      }
    }
  }

 private:
  Space* space_;
  bool* flag_;
};

bool HeapObject::ContainsPointersTo(Space* space) {
  bool has_pointer = false;
  ContainsPointerVisitor visitor(space, &has_pointer);
  IteratePointers(&visitor);
  return has_pointer;
}
#endif

}  // namespace dartino
