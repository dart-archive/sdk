// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
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

namespace fletch {

uint8 StaticClassStructures::meta_class_storage[Class::kSize];
uint8 StaticClassStructures::free_list_chunk_class_storage[Class::kSize];
uint8 StaticClassStructures::one_word_filler_class_storage[Class::kSize];

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

int HeapObject::Size() {
  // Fast check for non-variable length types.
  ASSERT(forwarding_address() == NULL);
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
    case InstanceFormat::FREE_LIST_CHUNK_TYPE:
      return FreeListChunk::cast(this)->size();
  }
  UNREACHABLE();
  return 0;
}

int HeapObject::FixedSize() {
  // Fast check for non variable length types.
  ASSERT(forwarding_address() == NULL);
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
  int len  = str->length();
  if (length() != len) return false;
  for (int i = 0; i < len; i++) {
    if (get_char_code(i) != str->get_char_code(i)) return false;
  }
  return true;
}

bool OneByteString::Equals(TwoByteString* str) {
  int len  = str->length();
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
  int len  = str->length();
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
  if (length >= 4 &&
      bytecodes[0] == kLoadLocal3 &&
      bytecodes[1] == kLoadField &&
      bytecodes[3] == kReturn) {
    result = reinterpret_cast<void*>(table->GetField());
  } else if (length >= 4 &&
             bytecodes[0] == kLoadLocal4 &&
             bytecodes[1] == kLoadLocal4 &&
             bytecodes[2] == kIdenticalNonNumeric &&
             bytecodes[3] == kReturn) {
    result = reinterpret_cast<void*>(table->ObjectEquals());
  } else if (length >= 5 &&
             bytecodes[0] == kLoadLocal4 &&
             bytecodes[1] == kLoadLocal4 &&
             bytecodes[2] == kStoreField &&
             bytecodes[4] == kReturn) {
    result = reinterpret_cast<void*>(table->SetField());
  } else if (length >= 3 &&
             bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListIndexGet) {
    result = reinterpret_cast<void*>(table->ListIndexGet());
  } else if (length >= 3 &&
             bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListIndexSet) {
    result = reinterpret_cast<void*>(table->ListIndexSet());
  } else if (length >= 3 &&
             bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListLength) {
    result = reinterpret_cast<void*>(table->ListLength());
  }
  return (reinterpret_cast<Object*>(result)->IsSmi()) ? result : NULL;
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

void Smi::SmiPrint() {
  Print::Out("%ld", value());
}

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
  intptr_t len = length();
  char* result = reinterpret_cast<char*>(malloc(len + 1));
  memcpy(result, byte_address_for(0), len);
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
  memcpy(byte_address_for(offset),
         x->byte_address_for(0),
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
  ASSERT(forwarding_address() == NULL);
  Class* old_class = get_class();
  Class* new_class = old_class->TransformationTarget();
  Array* transformation = old_class->Transformation();

  // NOTE: We do not pass 'immmutable = get_immutable()' here, since the
  // immutability bit and the identity hascode will get copied via the flags
  // word.
  Object* clone = heap->CreateInstance(new_class, Smi::FromWord(0), false);
  ASSERT(!clone->IsFailure());  // Needs to be in no-allocation-failure scope.
  Instance* target = Instance::cast(clone);

  // Copy the flags word from the old instance.
  target->SetFlagsBits(FlagsBits());

  int old_fields = old_class->NumberOfInstanceFields();
  int new_fields = new_class->NumberOfInstanceFields();

  int new_prefix = transformation->length() / 2;
  int old_prefix = new_prefix - (new_fields - old_fields);
  int suffix = new_fields - new_prefix;

  Object** new_fields_pointer = reinterpret_cast<Object**>(
      target->address() + Instance::kSize);
  Object** old_fields_pointer = reinterpret_cast<Object**>(
      address() + Instance::kSize);

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
    CopyBlock(new_fields_pointer + new_prefix,
              old_fields_pointer + old_prefix,
              suffix * sizeof(Object*));
  }

  // Zap old fields. This makes it possible to compute the size of a
  // transformed instance where it is hard to reach the class because
  // of the installed forwarding pointer.
  for (int i = 0; i < old_fields; i++) {
    *(old_fields_pointer + i) = reinterpret_cast<Object*>(HeapObject::kTag);
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
  int len  = length();
  for (int i = 0; i < len; i++) {
    Print::Out("  - [%d] = ", i);
    get(i)->ShortPrint();
    Print::Out("\n");
  }
}

void Array::ArrayShortPrint() {
  Print::Out("[");
  int len  = length();
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
  int len  = length();
  for (int i = 0; i < len; i++) {
    Print::Out("  - [%d] = %d\n", i, get(i));
  }
}

void ByteArray::ByteArrayShortPrint() {
  Print::Out("[");
  int len  = length();
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

void Double::DoubleShortPrint() {
  Print::Out("%f", value());
}

void Boxed::BoxedPrint() {
  Print::Out("- boxed: ");
  BoxedShortPrint();
  Print::Out("\n");
}

void Boxed::BoxedShortPrint() {
  value()->ShortPrint();
}

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

bool Class:: IsSubclassOf(Class* klass) {
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
  int size = instance_format().fixed_size();
  Print::Out("  - instance object size = %d\n", size);
  Print::Out("  - methods = ");
  methods()->ShortPrint();
  Print::Out("\n");
}

void Class::ClassShortPrint() {
  Print::Out("class");
}

void HeapObject::IteratePointers(PointerVisitor* visitor) {
  ASSERT(forwarding_address() == NULL);

  visitor->VisitClass(reinterpret_cast<Object**>(address()));
  uword raw = reinterpret_cast<uword>(raw_class());
  Class* klass = reinterpret_cast<Class*>(raw & ~HeapObject::kMarkBit);
  InstanceFormat format = klass->instance_format();
  // Fast case for fixed size object with all pointers.
  if (format.only_pointers_in_fixed_part()) {
    visitor->VisitBlock(
        reinterpret_cast<Object**>(address() + kPointerSize),
        reinterpret_cast<Object**>(address() + format.fixed_size()));
    return;
  }
  switch (format.type()) {
    case InstanceFormat::ARRAY_TYPE: {
      // We do not use cast method because the Array's class pointer is not
      // valid during marking.
      Array* array = reinterpret_cast<Array*>(this);
      visitor->VisitBlock(
          reinterpret_cast<Object**>(address() + (2*kPointerSize)),
          reinterpret_cast<Object**>(address() + array->ArraySize()));
      break;
    }

    case InstanceFormat::STACK_TYPE: {
      // We do not use cast method because the Stack's class pointer is not
      // valid during marking.
      Stack* stack = reinterpret_cast<Stack*>(this);
      visitor->VisitBlock(
          stack->Pointer(stack->top()),
          stack->Pointer(stack->length()));
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

HeapObject* HeapObject::forwarding_address() {
  Object* header = at(kClassOffset);
  if (!header->IsSmi()) return NULL;
  return HeapObject::FromAddress(reinterpret_cast<word>(header));
}

void HeapObject::set_forwarding_address(HeapObject* value) {
  ASSERT(forwarding_address() == NULL);
  at_put(kClassOffset, Smi::cast(reinterpret_cast<Smi*>(value->address())));
}

void Stack::UpdateFramePointers(Stack* old_stack) {
  Object** fp = Pointer(top());
  Object** old_fp = old_stack->Pointer(old_stack->top());
  word diff = (fp - old_fp) * kWordSize;
  while (*fp != NULL) {
    // Read the fp value and update it.
    Object* fp_value = *fp + diff;
    // Store back the updated value.
    *fp = fp_value;
    // Continue with the updated value as a new fp.
    fp = reinterpret_cast<Object**>(fp_value);
  }
}

HeapObject* HeapObject::CloneInToSpace(Space* to) {
  ASSERT(!to->Includes(this->address()));
  // If there is a forward pointer return it.
  HeapObject* f = forwarding_address();
  if (f != NULL) return f;
  // Otherwise, copy the object to the 'to' space
  // and insert a forward pointer.
  int object_size = Size();
  HeapObject* target =
      HeapObject::FromAddress(to->AllocateLinearly(object_size));
  // Copy the content of source to target.
  CopyBlock(reinterpret_cast<Object**>(target->address()),
            reinterpret_cast<Object**>(address()),
            object_size);
  if (target->IsStack()) {
    Stack::cast(target)->UpdateFramePointers(Stack::cast(this));
  }
  // Set the forwarding address.
  set_forwarding_address(target);

  return target;
}

Function* Function::UnfoldInToSpace(Space* to, int number_of_literals) {
  ASSERT(forwarding_address() == NULL);
  int current_object_size = Size();
  int new_object_size = current_object_size + number_of_literals * kPointerSize;
  HeapObject* target =
      HeapObject::FromAddress(to->AllocateLinearly(new_object_size));
  // Copy the content of source to target.
  CopyBlock(reinterpret_cast<Object**>(target->address()),
            reinterpret_cast<Object**>(address()),
            current_object_size);
  Function* result = Function::cast(target);
  result->set_literals_size(number_of_literals);
  ASSERT(result->Size() == Size() + number_of_literals * kPointerSize);
  // Set the forwarding address.
  set_forwarding_address(target);
  return result;
}

Function* Function::FoldInToSpace(Space* to) {
  ASSERT(forwarding_address() == NULL);
  int current_object_size = Size();
  int new_object_size = current_object_size - literals_size() * kPointerSize;
  HeapObject* target =
      HeapObject::FromAddress(to->AllocateLinearly(new_object_size));
  // Copy the content of source to target.
  CopyBlock(reinterpret_cast<Object**>(target->address()),
            reinterpret_cast<Object**>(address()),
            new_object_size);
  // Update literals size.
  Function* result = Function::cast(target);
  result->set_literals_size(0);
  // Set the forwarding address.
  set_forwarding_address(target);
  return result;
}

// Helper class for printing HeapObjects
class PrintVisitor: public PointerVisitor {
 public:
  void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) PrintPointer(p);
  }

  void VisitClass(Object** p) { }

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
    Print::Out("0x%lx: [%s] (%d): ",
                 address(),
                 title,
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

int SafeObjectPointerVisitor::Visit(HeapObject* object) {
  int size = object->Size();
  if (object->IsStack() && !process_->stacks_are_cooked()) {
    // To avoid visiting raw bytecode pointers lying on the stack we use a
    // stack walker.
    Frame frame(Stack::cast(object));
    while (frame.MovePrevious()) {
      visitor_->VisitBlock(frame.LastLocalAddress(),
                           frame.FirstLocalAddress() + 1);
    }
  } else {
    object->IteratePointers(visitor_);
  }
  return size;
}

}  // namespace fletch
