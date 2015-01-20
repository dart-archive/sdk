// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/object.h"

#include <stdio.h>
#include <stdlib.h>

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"

#include "src/vm/intrinsics.h"
#include "src/vm/natives.h"
#include "src/vm/program.h"

namespace fletch {


// Helper class to remove forward pointer when performing
// equivalence checks.

class UnmarkEquivalenceVisitor: public PointerVisitor {
 public:
  void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) {
      Object* object = *p;
      if (object->IsHeapObject()) {
        Unmark(HeapObject::cast(object));
      }
    }
  }

  void Unmark(HeapObject* object) {
    // An object is only marked if it has a
    // forwarding address and the referred object
    // has a forwarding address.
    HeapObject* f = object->forwarding_address();
    if (f == NULL) return;  // Not marked.
    HeapObject* g = f->forwarding_address();
    if (g == NULL) return;  // Not marked.
    ASSERT(g->IsClass());
    f->set_class(Class::cast(g));
    object->set_class(Class::cast(g));
    object->IteratePointers(this);
  }

  void VisitClass(Object** p) {
    // Ignore class pointer.
  }
};

bool Object::IsEquivalentTo(Object* other) {
  // First perform the recursive check.
  bool result = ObjectIsEquivalentTo(other);
  if (IsHeapObject()) {
    // Then remove all inserted forwarding pointers.
    UnmarkEquivalenceVisitor visitor;
    visitor.Unmark(HeapObject::cast(this));
  }
  return result;
}

bool Object::ObjectIsEquivalentTo(Object* other) {
  if (this == other) return true;
  if (IsSmi() || other->IsSmi()) return false;
  bool result =
      HeapObject::cast(this)->HeapObjectIsEquivalentTo(HeapObject::cast(other));
  return result;
}

HeapObject* const HeapObject::kIllegal =
    reinterpret_cast<HeapObject*>(0xdeadbead);


HeapObject* HeapObject::EquivalentForwardingAddress() {
  // Check for forwarding pointers in this and other.
  HeapObject* f = forwarding_address();
  if (f == NULL) return NULL;
  if (f->forwarding_address() == NULL) return NULL;
  return f;
}

bool HeapObject::HeapObjectIsEquivalentTo(HeapObject* other) {
  ASSERT(this != other);  // Dealt with in ObjectIsEquivalentTo.
  if (forwarding_address() != NULL || other->forwarding_address() != NULL) {
    HeapObject* f = EquivalentForwardingAddress();
    if (f != NULL) return f == other;
    return this == other->EquivalentForwardingAddress();
  }
  ASSERT(forwarding_address() == NULL);
  ASSERT(other->forwarding_address() == NULL);

  // Check they have same class.
  if (raw_class() != other->raw_class()) return false;

  // Dispatch to string, array, or double. Otherwise return false;
  switch (raw_class()->instance_format().type()) {
    case InstanceFormat::STRING_TYPE:
      return String::cast(this)->StringIsEquivalentTo(String::cast(other));
    case InstanceFormat::ARRAY_TYPE:
      return Array::cast(this)->ArrayIsEquivalentTo(Array::cast(other));
    case InstanceFormat::DOUBLE_TYPE:
      return Double::cast(this)->DoubleIsEquivalentTo(Double::cast(other));
    case InstanceFormat::INSTANCE_TYPE:
      return Instance::cast(this)->
          InstanceIsEquivalentTo(Instance::cast(other));
    default:
      // Other object types only check object identity.
      return false;
  }
}

void HeapObject::SetEquivalentForwarding(HeapObject* other) {
  ASSERT(this != other);
  ASSERT(raw_class() == other->raw_class());
  set_forwarding_address(other);
  other->set_forwarding_address(other->get_class());
}

bool Array::ArrayIsEquivalentTo(Array* other) {
  SetEquivalentForwarding(other);
  if (length() != other->length()) return false;
  for (int i = 0; i < length(); i++) {
    if (!get(i)->ObjectIsEquivalentTo(other->get(i))) return false;
  }
  return true;
}

bool String::StringIsEquivalentTo(String* other) {
  SetEquivalentForwarding(other);
  return Equals(other);
}

bool Instance::InstanceIsEquivalentTo(Instance* other) {
  // Remember to read the format before setting the forward pointer.
  InstanceFormat format = raw_class()->instance_format();
  SetEquivalentForwarding(other);
  for (int offset = HeapObject::kSize;
       offset < format.fixed_size();
       offset += kPointerSize) {
    if (!at(offset)->ObjectIsEquivalentTo(other->at(offset))) return false;
  }
  return true;
}

int HeapObject::Size() {
  // Fast check for non variable length types.
  InstanceFormat format = raw_class()->instance_format();
  if (!format.has_variable_part()) return format.fixed_size();
  int type = format.type();
  // Strings.
  if (type == InstanceFormat::STRING_TYPE) {
    return String::cast(this)->StringSize();
  }
  // Arrays.
  if (type == InstanceFormat::ARRAY_TYPE) {
    return Array::cast(this)->ArraySize();
  }
  // ByteArrays.
  if (type == InstanceFormat::BYTE_ARRAY_TYPE) {
    return ByteArray::cast(this)->ByteArraySize();
  }
  // Functions.
  if (type == InstanceFormat::FUNCTION_TYPE) {
    return Function::cast(this)->FunctionSize();
  }
  // Stacks.
  if (type == InstanceFormat::STACK_TYPE) {
    return Stack::cast(this)->StackSize();
  }
  UNREACHABLE();
  return 0;
}

int HeapObject::FixedSize() {
  // Fast check for non variable length types.
  InstanceFormat format = raw_class()->instance_format();
  return format.fixed_size();
}

bool String::Equals(List<const char> str) {
  int us = str.length();
  if (length() != us) return false;
  for (int i = 0; i < us; i++) {
    if (get_char(i) != str[i]) return false;
  }
  return true;
}

bool String::Equals(String* str) {
  if (this == str) return true;
  int len  = str->length();
  if (length() != len) return false;
  for (int i = 0; i < len; i++) {
    if (get_char(i) != str->get_char(i)) return false;
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
  // Read delta.
  int delta = Utils::ReadInt32(bcp + 1);
  if (frame_ranges_offset != NULL) {
    *frame_ranges_offset = delta + kMethodEndLength;
  }
  uword address = reinterpret_cast<uword>(bcp - delta - kSize);
  return Function::cast(HeapObject::FromAddress(address));
}

void* Function::ComputeIntrinsic() {
  int length = bytecode_size();
  uint8* bytecodes = bytecode_address_for(0);
  if (length >= 4 &&
      bytecodes[0] == kLoadLocal1 &&
      bytecodes[1] == kLoadField &&
      bytecodes[3] == kReturn) {
    return reinterpret_cast<void*>(&Intrinsic_GetField);
  } else if (length >= 5 &&
             bytecodes[0] == kLoadLocal2 &&
             bytecodes[1] == kLoadLocal2 &&
             bytecodes[2] == kStoreField &&
             bytecodes[4] == kReturn) {
    return reinterpret_cast<void*>(&Intrinsic_SetField);
  } else if (length >= 3 &&
             bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListIndexGet) {
    return reinterpret_cast<void*>(&Intrinsic_ListIndexGet);
  } else if (length >= 3 &&
             bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListIndexSet) {
    return reinterpret_cast<void*>(&Intrinsic_ListIndexSet);
  } else if (length >= 3 &&
             bytecodes[0] == kInvokeNative &&
             bytecodes[2] == kListLength) {
    return reinterpret_cast<void*>(&Intrinsic_ListLength);
  }
  return NULL;
}

void Object::Print() {
  if (IsSmi()) {
    Smi::cast(this)->SmiPrint();
  } else {
    HeapObject::cast(this)->HeapObjectPrint();
  }
  printf("\n\n");
  fflush(stdout);
}

void Object::ShortPrint() {
  if (IsSmi()) {
    Smi::cast(this)->SmiPrint();
  } else {
    HeapObject::cast(this)->HeapObjectShortPrint();
  }
}

void Smi::SmiPrint() {
  printf("%ld", value());
}

void String::StringPrint() {
  RawPrint("String");
  int len  = length();
  printf("\"");
  for (int i = 0; i < len; i++) printf("%c", get_char(i));
  printf("\"");
}

void String::StringShortPrint() {
  int len  = length();
  for (int i = 0; i < len; i++) printf("%c", get_char(i));
}

char* String::ToCString() {
  int len = length();
  char* result = reinterpret_cast<char*>(malloc(len + 1));
  for (int i = 0; i < len; i++) {
    char c = get_char(i);
    if (c == '\0') {
      FATAL("Converting string with zero bytes to C string");
    }
    result[i] = c;
  }
  result[len] = '\0';
  return result;
}

void Instance::InstancePrint() {
  RawPrint("Instance");
  printf("\n");
  printf("  - class = ");
  get_class()->ShortPrint();
  int fields = get_class()->NumberOfInstanceFields();
  for (int i = 0; i < fields; i++) {
    printf("  - @%d = ", i);
    GetInstanceField(i)->ShortPrint();
    printf("\n");
  }
}

void Instance::InstanceShortPrint() {
  if (IsNull()) {
    printf("null");
  } else {
    Class* clazz = get_class();
    printf("instance of ");
    clazz->ShortPrint();
  }
}

void Array::ArrayPrint() {
  RawPrint("Array");
  printf("\n");
  printf("  - length = %d\n", length());
  int len  = length();
  for (int i = 0; i < len; i++) {
    printf("  - [%d] = ", i);
    get(i)->ShortPrint();
    printf("\n");
  }
}

void Array::ArrayShortPrint() {
  printf("[");
  int len  = length();
  for (int i = 0; i < len; i++) {
    get(i)->ShortPrint();
    if (i + 1 < len) printf(", ");
  }
  printf("]");
}

void ByteArray::ByteArrayPrint() {
  RawPrint("ByteArray");
  printf("\n");
  printf("  - length = %d\n", length());
  int len  = length();
  for (int i = 0; i < len; i++) {
    printf("  - [%d] = %d\n", i, get(i));
  }
}

void ByteArray::ByteArrayShortPrint() {
  printf("[");
  int len  = length();
  for (int i = 0; i < len; i++) {
    printf("%d", get(i));
    if (i + 1 < len) printf(", ");
  }
  printf("]");
}

void Function::FunctionPrint() {
  RawPrint("Function");
  printf("\n");
  printf("  - bytecode_size = %d\n", bytecode_size());
}

void Function::FunctionShortPrint() {
  printf("function #%d", bytecode_size());
}

void LargeInteger::LargeIntegerPrint() {
  printf("- large integer: ");
  LargeIntegerShortPrint();
  printf("\n");
}

void LargeInteger::LargeIntegerShortPrint() {
  printf("%lld", static_cast<long long int>(value()));  // NOLINT
}

void Double::DoublePrint() {
  printf("- double: ");
  DoubleShortPrint();
  printf("\n");
}

void Double::DoubleShortPrint() {
  printf("%f", value());
}

void Boxed::BoxedPrint() {
  printf("- boxed: ");
  BoxedShortPrint();
  printf("\n");
}

void Boxed::BoxedShortPrint() {
  value()->ShortPrint();
}

void Initializer::InitializerPrint() {
  printf("- initializer: ");
  printf("initializer: ");
  function()->Print();
  printf("\n");
}

void Initializer::InitializerShortPrint() {
  printf("initializer ");
  function()->ShortPrint();
  printf("\n");
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
  printf("\n");
  printf("\n");
  if (instance_format().type() == InstanceFormat::INSTANCE_TYPE) {
    printf("  - number of instance fields = %d\n", NumberOfInstanceFields());
  }
  int size = instance_format().fixed_size();
  printf("  - instance object size = %d\n", size);
  printf("  - methods = ");
  methods()->ShortPrint();
  printf("\n");
}

void Class::ClassShortPrint() {
  printf("class");
}

void HeapObject::IteratePointers(PointerVisitor* visitor) {
  visitor->VisitClass(reinterpret_cast<Object**>(address()));
  InstanceFormat format = raw_class()->instance_format();
  // Fast case for fixed size object with all pointers.
  if (format.only_pointers_in_fixed_part()) {
    visitor->VisitBlock(
        reinterpret_cast<Object**>(address() + kPointerSize),
        reinterpret_cast<Object**>(address() + format.fixed_size()));
    return;
  }
  switch (format.type()) {
    case InstanceFormat::ARRAY_TYPE:
      visitor->VisitBlock(
          reinterpret_cast<Object**>(address() + (2*kPointerSize)),
          reinterpret_cast<Object**>(address() + Array::cast(this)->Size()));
      break;

    case InstanceFormat::STACK_TYPE: {
      Stack* stack = Stack::cast(this);
      visitor->VisitBlock(
          reinterpret_cast<Object**>(address() + Stack::kSize),
          // Include the top pointer in the block.
          stack->Pointer(stack->top() + 1));
      break;
    }

    case InstanceFormat::FUNCTION_TYPE: {
      Function* function = Function::cast(this);
      Object** first = function->literal_address_for(0);
      visitor->VisitBlock(first, first + function->literals_size());
      break;
    }

    case InstanceFormat::LARGE_INTEGER_TYPE:
    case InstanceFormat::DOUBLE_TYPE:
      // No pointers in these objects.
      // TODO(vitalyr): we might want to have
      // only_non_pointers_in_fixed_part for types like these.
      break;

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

static void CopyBlock(Object** dst, Object** src, int byte_size) {
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

HeapObject* HeapObject::CloneInToSpace(Space* to) {
  ASSERT(!to->Includes(this->address()));
  // If there is a forward pointer return it.
  HeapObject* f = forwarding_address();
  if (f != NULL) return f;
  // Otherwise, copy the object to the 'to' space
  // and insert a forward pointer.
  int object_size = Size();
  HeapObject* target = HeapObject::FromAddress(to->Allocate(object_size));
  // Copy the content of source to target.
  CopyBlock(reinterpret_cast<Object**>(target->address()),
            reinterpret_cast<Object**>(address()),
            object_size);
  // Set the forwarding address.
  set_forwarding_address(target);
  return target;
}

Function* Function::UnfoldInToSpace(Space* to, int number_of_literals) {
  ASSERT(forwarding_address() == NULL);
  int current_object_size = Size();
  int new_object_size = current_object_size + number_of_literals * kPointerSize;
  HeapObject* target = HeapObject::FromAddress(to->Allocate(new_object_size));
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
  HeapObject* target = HeapObject::FromAddress(to->Allocate(new_object_size));
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
    printf(" [0x%lx] = ", reinterpret_cast<uword>(p));
    (*p)->ShortPrint();
    printf("\n");
  }
};

void HeapObject::RawPrint(const char* title) {
  if (!Flags::IsOn("verbose")) {
    printf("a %s: ", title);
  } else {
    printf("0x%lx: [%s] (%d): ", address(), title, static_cast<int>(Size()));
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
    case InstanceFormat::STRING_TYPE:
      String::cast(this)->StringPrint();
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
    case InstanceFormat::STRING_TYPE:
      String::cast(this)->StringShortPrint();
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

}  // namespace fletch
