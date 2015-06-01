// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/snapshot.h"

#include <stdio.h>
#include <stdlib.h>

#include "src/shared/assert.h"
#include "src/shared/utils.h"

#include "src/vm/object.h"
#include "src/vm/program.h"

namespace fletch {

static const int kSupportedSizeOfDouble = 8;
static const int kReferenceTableSizeBytes = 4;
static const int kHeapSizeBytes = 4;

class Header {
 public:
  explicit Header(word value) : value_(value) {}

  static Header FromSmi(Smi* value) {
    Header h((value->value() << kSmiShift) | kSmiTag);
    ASSERT(h.is_smi());
    ASSERT(h.as_smi() == value);
    return h;
  }

  static Header FromIndex(word value) {
    Header h((value << kIndexFieldShift) | kIndexTag);
    ASSERT(h.is_index());
    ASSERT(h.as_index() == value);
    return h;
  }

  static Header FromTypeAndElements(InstanceFormat::Type type,
                                    bool immutable,
                                    int elements = 0) {
    Header h = Header(
        TypeField::encode(type) |
        ImmutableField::encode(immutable) |
        ElementsField::encode(elements) |
        kTypeAndElementsTag);
    ASSERT(h.is_type());
    ASSERT(type == h.as_type());
    ASSERT(immutable == h.immutable());
    ASSERT(elements == h.elements());
    return h;
  }

  // Compute the object size based on type and elements.
  int Size() {
    switch (as_type()) {
      case InstanceFormat::STRING_TYPE:
        return String::AllocationSize(elements());
      case InstanceFormat::ARRAY_TYPE:
        return Array::AllocationSize(elements());
      case InstanceFormat::BYTE_ARRAY_TYPE:
        return ByteArray::AllocationSize(elements());
      case InstanceFormat::LARGE_INTEGER_TYPE:
        return LargeInteger::AllocationSize();
      case InstanceFormat::INSTANCE_TYPE:
        return Instance::AllocationSize(elements());
      case InstanceFormat::CLASS_TYPE:
        return Class::AllocationSize();
      case InstanceFormat::FUNCTION_TYPE:
        return Function::AllocationSize(elements());
      case InstanceFormat::DOUBLE_TYPE:
        return Double::AllocationSize();
      case InstanceFormat::INITIALIZER_TYPE:
        return Initializer::AllocationSize();
      default:
        UNREACHABLE();
        return 0;
    }
  }

  bool is_smi() { return (value_ & kSmiMask) == kSmiTag; }
  Smi* as_smi() {
    ASSERT(is_smi());
    return Smi::FromWord(value_ >> kSmiShift);
  }

  bool is_index() { return (value_ & kTagMask) == kIndexTag; }
  word as_index() {
    ASSERT(is_index());
    return value_ >> kIndexFieldShift;
  }

  bool is_type() { return (value_ & kTagMask) == kTypeAndElementsTag; }
  InstanceFormat::Type as_type() {
    ASSERT(is_type());
    return TypeField::decode(value_);
  }

  int elements() {
    ASSERT(is_type());
    return ElementsField::decode(value_);
  }

  bool immutable() {
    ASSERT(is_type());
    return ImmutableField::decode(value_);
  }

  word as_word() { return value_; }

  // Lowest one/two bits are used for tagging between:
  // Smi, Indexed and Type+Elements.
  static const int kSmiMask = 1;
  static const int kTagMask = 3;

  static const int kSmiTag = 0;
  static const int kIndexTag = 1;
  static const int kTypeAndElementsTag = 3;

  static const int kIndexFieldShift = 2;
  static const int kSmiShift = 1;

  // Fields in case of Type + Elements encoding.
  class TypeField : public BitField<InstanceFormat::Type, 2, 4> {};
  class ImmutableField : public BoolField<6> {};
  class ElementsField: public BitField<word, 7, 25> {};
 private:
  word value_;
};

class ObjectInfo {
 public:
  ObjectInfo(Class* the_class, int index)
      : the_class_(the_class), index_(index) { }
  Class* the_class() { return the_class_; }
  int index() { return index_; }

 private:
  Class* the_class_;
  int index_;
};

class ReaderVisitor: public PointerVisitor {
 public:
  explicit ReaderVisitor(SnapshotReader* reader) : reader_(reader) { }

  void Visit(Object** p) { *p = reader_->ReadObject(); }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) *p = reader_->ReadObject();
  }
 private:
  SnapshotReader* reader_;
};

class WriterVisitor: public PointerVisitor {
 public:
  explicit WriterVisitor(SnapshotWriter* writer) : writer_(writer) { }

  void Visit(Object** p) { writer_->WriteObject(*p); }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) writer_->WriteObject(*p);
  }
 private:
  SnapshotWriter* writer_;
};

class UnmarkSnapshotVisitor: public PointerVisitor {
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
    word f = object->forwarding_word();
    if (f == 0) return;  // Not marked.
    ObjectInfo* info = reinterpret_cast<ObjectInfo*>(f);
    object->set_class(info->the_class());
    delete info;
    object->IteratePointers(this);
  }
};

class UnmarkVisitor: public PointerVisitor {
 public:
  UnmarkVisitor() { }

  void Visit(Object** p) { Unmark(*p); }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) Unmark(*p);
  }

 private:
  void Unmark(Object* object)  {
    if (object->IsHeapObject()) {
      UnmarkSnapshotVisitor visitor;
      visitor.Unmark(HeapObject::cast(object));
    }
  }
};

void SnapshotReader::AddReference(HeapObject* object) {
  backward_references_[index_++] = object;
}

HeapObject* SnapshotReader::Dereference(int index) {
  return backward_references_[index - 1];
}

void SnapshotWriter::WriteByte(uint8 value) {
  EnsureCapacity(1);
  snapshot_[position_++] = value;
}

void SnapshotReader::ReadBytes(int length, uint8* values) {
  memcpy(values, &snapshot_[position_], length);
  position_ += length;
}

void SnapshotWriter::WriteBytes(int length, uint8* values) {
  EnsureCapacity(length);
  memcpy(&snapshot_[position_], values, length);
  position_ += length;
}

word SnapshotReader::ReadWord() {
  word r = 0;
  word s = 0;
  uint8 b = ReadByte();
  while (b < 128) {
    r |= static_cast<word>(b) << s;
    s += 7;
    b = ReadByte();
  }
  return r | ((static_cast<word>(b) - 192) << s);
}

void SnapshotWriter::WriteWord(word value) {
  while (value < -64 || value >= 64) {
    WriteByte(static_cast<uint8>(value & 127));
    value = value >> 7;
  }
  WriteByte(static_cast<uint8>(value + 192));
}

int64 SnapshotReader::ReadInt64() {
  int64 r = 0;
  int64 s = 0;
  uint8 b = ReadByte();
  while (b < 128) {
    r |= static_cast<int64>(b) << s;
    s += 7;
    b = ReadByte();
  }
  return r | ((static_cast<int64>(b) - 192) << s);
}

void SnapshotWriter::WriteInt64(int64 value) {
  while (value < -64 || value >= 64) {
    WriteByte(static_cast<uint8>(value & 127));
    value = value >> 7;
  }
  WriteByte(static_cast<uint8>(value + 192));
}

double SnapshotReader::ReadDouble() {
  double result = 0.0;
  uint8* p_data = reinterpret_cast<uint8*>(&result);
  ASSERT(sizeof(double) == kSupportedSizeOfDouble);
  ReadBytes(kSupportedSizeOfDouble, p_data);
  return result;
}

void SnapshotWriter::WriteDouble(double value) {
  uint8* p_data = reinterpret_cast<uint8*>(&value);
  WriteBytes(kSupportedSizeOfDouble, p_data);
}

void SnapshotWriter::WriteHeader(InstanceFormat::Type type, bool immutable,
                                 int elements) {
  WriteWord(Header::FromTypeAndElements(type, immutable, elements).as_word());
}

Program* SnapshotReader::ReadProgram() {
  if (ReadByte() != 0xbe) FATAL("Snapshot has wrong magic header!\n");
  if (ReadByte() != 0xef) FATAL("Snapshot has wrong magic header!\n");

  // Read the required backward reference table size.
  int references = 0;
  for (int i = 0; i < kReferenceTableSizeBytes; i++) {
    references = (references << 8) | ReadByte();
  }

  Program* program = new Program();

  // Read the heap size and allocate an area for it.
  int size_position = position_ + ((kPointerSize == 4) ? 0 : kHeapSizeBytes);
  position_ += 2 * kHeapSizeBytes;
  int heap_size = ReadHeapSizeFrom(size_position);
  memory_ = ObjectMemory::AllocateChunk(program->heap()->space(), heap_size);
  top_ = memory_->base();

  // Allocate space for the backward references.
  backward_references_ = List<HeapObject*>::New(references);

  // Read all the program state (except roots).
  program->set_entry(Function::cast(ReadObject()));
  program->set_main_arity(ReadWord());
  program->set_classes(ReadObject());
  program->set_constants(ReadObject());
  program->set_static_methods(ReadObject());
  program->set_static_fields(ReadObject());
  program->set_dispatch_table(ReadObject());
  program->set_vtable(ReadObject());

  // Read the roots.
  ReaderVisitor visitor(this);
  program->IterateRoots(&visitor);

  program->heap()->space()->AppendProgramChunk(memory_, top_);
  backward_references_.Delete();

  // Programs read from a snapshot are always compact.
  program->set_is_compact(true);
  program->SetupDispatchTableIntrinsics();

  return program;
}

List<uint8> SnapshotWriter::WriteProgram(Program* program) {
  WriteByte(0xbe);
  WriteByte(0xef);

  // Reserve space for the backward reference table size.
  int reference_count_position = position_;
  for (int i = 0; i < kReferenceTableSizeBytes; i++) WriteByte(0);

  // Make sure that the program is in the compact form before
  // snapshotting.
  if (!program->is_compact()) program->Fold();
  ASSERT(program->is_compact());
  program->ClearDispatchTableIntrinsics();

  // Reserve space for the size of the heap.
  int size_position =
      position_ + ((kPointerSize == 4) ? 0 : kHeapSizeBytes);
  int alternative_size_position =
      position_ + ((kPointerSize == 4) ? kHeapSizeBytes : 0);
  for (int i = 0; i < 2 * kHeapSizeBytes; i++) WriteByte(0);

  // Write all the program state (except roots).
  WriteObject(program->entry());
  WriteWord(program->main_arity());
  WriteObject(program->classes());
  WriteObject(program->constants());
  WriteObject(program->static_methods());
  WriteObject(program->static_fields());
  WriteObject(program->dispatch_table());
  WriteObject(program->vtable());

  // Write out all the roots of the program.
  WriterVisitor visitor(this);
  program->IterateRoots(&visitor);

  // TODO(kasperl): Unmark all touched objects. Right now, we
  // only unmark the roots.
  UnmarkVisitor unmarker;
  program->IterateRoots(&unmarker);

  // Write out the required size of the backward reference table
  // at the beginning of the snapshot.
  int references = index_ - 1;
  for (int i = kReferenceTableSizeBytes - 1; i >= 0; i--) {
    snapshot_[reference_count_position + i] = references & 0xFF;
    references >>= 8;
  }
  ASSERT(references == 0);

  // Write the size of the heap.
  WriteHeapSizeTo(size_position, program->heap()->space()->Used());
  WriteHeapSizeTo(alternative_size_position, alternative_heap_size_);

  return snapshot_.Sublist(0, position_);
}

Object* SnapshotReader::ReadObject() {
  Header header(ReadWord());
  if (header.is_smi()) {
    // The header word indicates that this is an encoded small integer.
    return header.as_smi();
  } else if (header.is_index()) {
    // The header word indicates that this is a backreference.
    word index = header.as_index();
    ASSERT(index < 0);
    return Dereference(-index);
  }

  int elements = header.elements();
  InstanceFormat::Type type = header.as_type();

  int size = header.Size();
  HeapObject* object = Allocate(size);

  AddReference(object);
  object->set_class(reinterpret_cast<Class*>(ReadObject()));
  object->set_immutable(header.immutable());
  switch (type) {
    case InstanceFormat::STRING_TYPE:
      reinterpret_cast<String*>(object)->StringReadFrom(this, elements);
      break;
    case InstanceFormat::ARRAY_TYPE:
      reinterpret_cast<Array*>(object)->ArrayReadFrom(this, elements);
      break;
    case InstanceFormat::BYTE_ARRAY_TYPE:
      reinterpret_cast<ByteArray*>(object)->ByteArrayReadFrom(this, elements);
      break;
    case InstanceFormat::LARGE_INTEGER_TYPE:
      reinterpret_cast<LargeInteger*>(object)->LargeIntegerReadFrom(this);
      break;
    case InstanceFormat::CLASS_TYPE:
      reinterpret_cast<Class*>(object)->ClassReadFrom(this);
      break;
    case InstanceFormat::FUNCTION_TYPE:
      reinterpret_cast<Function*>(object)->FunctionReadFrom(this, elements);
      break;
    case InstanceFormat::DOUBLE_TYPE:
      reinterpret_cast<Double*>(object)->DoubleReadFrom(this);
      break;
    case InstanceFormat::INSTANCE_TYPE:
      reinterpret_cast<Instance*>(object)->InstanceReadFrom(this, elements);
      break;
    case InstanceFormat::INITIALIZER_TYPE: {
      Initializer* initializer = reinterpret_cast<Initializer*>(object);
      initializer->InitializerReadFrom(this);
      break;
    }
    default:
      UNIMPLEMENTED();
  }

  return object;
}

void SnapshotWriter::WriteObject(Object* object) {
  // First check if object is small integer.
  if (object->IsSmi()) {
    WriteWord(Header::FromSmi(Smi::cast(object)).as_word());
    return;
  }

  HeapObject* heap_object = HeapObject::cast(object);
  // Then check possible backward reference.
  word f = heap_object->forwarding_word();
  if (f != 0) {
    ObjectInfo* info = reinterpret_cast<ObjectInfo*>(f);
    WriteWord(Header::FromIndex(-info->index()).as_word());
    return;
  }

  Class* klass = ClassFor(heap_object);
  InstanceFormat::Type type = klass->instance_format().type();

  // Serialize the object.
  switch (type) {
    case InstanceFormat::STRING_TYPE: {
      String* str = String::cast(object);
      alternative_heap_size_ += str->AlternativeSize();
      str->StringWriteTo(this, klass);
      break;
    }
    case InstanceFormat::ARRAY_TYPE: {
      Array* array = Array::cast(object);
      alternative_heap_size_ += array->AlternativeSize();
      array->ArrayWriteTo(this, klass);
      break;
    }
    case InstanceFormat::BYTE_ARRAY_TYPE: {
      ByteArray* array = ByteArray::cast(object);
      alternative_heap_size_ += array->AlternativeSize();
      array->ByteArrayWriteTo(this, klass);
      break;
    }
    case InstanceFormat::LARGE_INTEGER_TYPE: {
      LargeInteger* integer = LargeInteger::cast(object);
      alternative_heap_size_ += integer->AlternativeSize();
      integer->LargeIntegerWriteTo(this, klass);
      break;
    }
    case InstanceFormat::INSTANCE_TYPE: {
      Instance* instance = Instance::cast(object);
      alternative_heap_size_ += instance->AlternativeSize(klass);
      instance->InstanceWriteTo(this, klass);
      break;
    }
    case InstanceFormat::CLASS_TYPE: {
      Class* klass = Class::cast(object);
      alternative_heap_size_ += klass->AlternativeSize();
      klass->ClassWriteTo(this, klass);
      break;
    }
    case InstanceFormat::FUNCTION_TYPE: {
      Function* function = Function::cast(object);
      alternative_heap_size_ += function->AlternativeSize();
      function->FunctionWriteTo(this, klass);
      break;
    }
    case InstanceFormat::DOUBLE_TYPE: {
      Double* d = Double::cast(object);
      alternative_heap_size_ += d->AlternativeSize();
      d->DoubleWriteTo(this, klass);
      break;
    }
    case InstanceFormat::INITIALIZER_TYPE: {
      Initializer* initializer = Initializer::cast(object);
      alternative_heap_size_ += initializer->AlternativeSize();
      initializer->InitializerWriteTo(this, klass);
      break;
    }
    default:
      // Unable to handle this type of object.
      UNREACHABLE();
  }
}

int SnapshotReader::ReadHeapSizeFrom(int position) {
  int size = 0;
  for (int i = 0; i < kHeapSizeBytes; i++) {
    size = (size << 8) | snapshot_[position + i];
  }
  return size;
}

void SnapshotWriter::WriteHeapSizeTo(int position, int size) {
  for (int i = kHeapSizeBytes - 1; i >= 0; i--) {
    snapshot_[position + i] = size & 0xFF;
    size >>= 8;
  }
}

Class* SnapshotWriter::ClassFor(HeapObject* object) {
  ASSERT(object->forwarding_word() == 0);
  return object->raw_class();
}

void SnapshotWriter::Forward(HeapObject* object) {
  Class* klass = ClassFor(object);
  ObjectInfo* info = new ObjectInfo(object->raw_class(), index_++);
  object->set_forwarding_word(reinterpret_cast<word>(info));
  ASSERT(object->forwarding_word() != 0);
  WriteObject(klass);
}

void SnapshotWriter::GrowCapacity(int extra) {
  int growth = Utils::Maximum(1 * MB, extra);
  int capacity = snapshot_.length() + growth;
  uint8* data = static_cast<uint8*>(realloc(snapshot_.data(), capacity));
  snapshot_ = List<uint8>(data, capacity);
}

void String::StringWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::STRING_TYPE, get_immutable(), length());
  writer->Forward(this);
  // Body.
  writer->WriteWord(IdentityHashCode()->value());
  writer->WriteBytes(length() * sizeof(uint16_t), byte_address_for(0));
}

void String::StringReadFrom(SnapshotReader* reader, int length) {
  set_length(length);
  set_hash_value(kNoHashValue);
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  reader->ReadBytes(length * sizeof(uint16_t), byte_address_for(0));
}

void Array::ArrayWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::ARRAY_TYPE, get_immutable(), length());
  writer->Forward(this);
  // Body.
  writer->WriteWord(IdentityHashCode()->value());
  for (int i = 0; i < length(); i++) {
    writer->WriteObject(get(i));
  }
}

void Array::ArrayReadFrom(SnapshotReader* reader, int length) {
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  set_length(length);
  for (int i = 0; i < length; i++) set(i, reader->ReadObject());
}

void ByteArray::ByteArrayWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::BYTE_ARRAY_TYPE, get_immutable(),
                      length());
  writer->Forward(this);
  // Body.
  writer->WriteWord(IdentityHashCode()->value());
  writer->WriteBytes(length(), byte_address_for(0));
}

void ByteArray::ByteArrayReadFrom(SnapshotReader* reader, int length) {
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  set_length(length);
  reader->ReadBytes(length, byte_address_for(0));
}

void Instance::InstanceWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  int nof = klass->NumberOfInstanceFields();
  writer->WriteHeader(klass->instance_format().type(), get_immutable(), nof);
  writer->Forward(this);
  // Body
  writer->WriteWord(IdentityHashCode()->value());
  for (int i = 0; i < nof; i++) {
    writer->WriteObject(GetInstanceField(i));
  }
}

void Instance::InstanceReadFrom(SnapshotReader* reader, int fields) {
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  int size = AllocationSize(fields);
  for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

void Class::ClassWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::CLASS_TYPE, get_immutable());
  writer->Forward(this);
  // Body.
  writer->WriteWord(IdentityHashCode()->value());
  int size = AllocationSize();
  for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
    writer->WriteObject(at(offset));
  }
}

void Class::ClassReadFrom(SnapshotReader* reader) {
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  int size = AllocationSize();
  for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

void Function::FunctionWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  int rounded_bytecode_size = BytecodeAllocationSize(bytecode_size());
  ASSERT(literals_size() == 0);
  writer->WriteHeader(InstanceFormat::FUNCTION_TYPE, get_immutable(),
                      rounded_bytecode_size);
  writer->Forward(this);
  // Body.
  writer->WriteWord(IdentityHashCode()->value());
  for (int offset = HeapObject::kSize;
       offset < Function::kSize;
       offset += kPointerSize) {
    writer->WriteObject(at(offset));
  }
  writer->WriteBytes(bytecode_size(), bytecode_address_for(0));
  int offset = Function::kSize + rounded_bytecode_size;
  for (int i = 0; i < literals_size(); ++i) {
    writer->WriteObject(at(offset + i * kPointerSize));
  }
}

void Function::FunctionReadFrom(SnapshotReader* reader, int length) {
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  for (int offset = HeapObject::kSize;
       offset < Function::kSize;
       offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
  reader->ReadBytes(bytecode_size(), bytecode_address_for(0));
  int rounded_bytecode_size = BytecodeAllocationSize(bytecode_size());
  int offset = Function::kSize + rounded_bytecode_size;
  for (int i = 0; i < literals_size(); ++i) {
    at_put(offset + i * kPointerSize, reader->ReadObject());
  }
}

void LargeInteger::LargeIntegerWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::LARGE_INTEGER_TYPE, get_immutable());
  writer->Forward(this);
  // Body.
  writer->WriteWord(IdentityHashCode()->value());
  writer->WriteInt64(value());
}

void LargeInteger::LargeIntegerReadFrom(SnapshotReader* reader) {
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  set_value(reader->ReadInt64());
}

void Double::DoubleWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::DOUBLE_TYPE, get_immutable());
  writer->Forward(this);
  // Body.
  writer->WriteWord(IdentityHashCode()->value());
  writer->WriteDouble(value());
}

void Double::DoubleReadFrom(SnapshotReader* reader) {
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  set_value(reader->ReadDouble());
}

void Initializer::InitializerWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::INITIALIZER_TYPE, get_immutable());
  writer->Forward(this);
  // Body.
  writer->WriteWord(IdentityHashCode()->value());
  for (int offset = HeapObject::kSize;
       offset < Initializer::kSize;
       offset += kPointerSize) {
    writer->WriteObject(at(offset));
  }
}

void Initializer::InitializerReadFrom(SnapshotReader* reader) {
  SetIdentityHashCode(Smi::FromWord(reader->ReadWord()));
  for (int offset = HeapObject::kSize;
       offset < Initializer::kSize;
       offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

}  // namespace fletch
