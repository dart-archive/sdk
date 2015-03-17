// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/snapshot.h"

#include <stdio.h>
#include <stdlib.h>

#include "src/shared/assert.h"

#include "src/vm/object.h"
#include "src/vm/program.h"

namespace fletch {

static const int kSupportedSizeOfDouble = 8;
static const int kReferenceTableSizeBytes = 4;

class Header {
 public:
  explicit Header(word value) : value_(value) {}

  static Header FromSmi(Smi* value) { return Header(value->value() << 1); }
  static Header FromIndex(word value) { return Header((value << 2) | 1); }
  static Header FromTypeAndElements(InstanceFormat::Type type,
                                    int elements = 0) {
    // Format: <elements:24><type:4><11>
    Header result =
        Header((elements << 6) | (static_cast<word>(type) << 2) | 3);
    ASSERT(elements == result.elements());
    ASSERT(type == result.as_type());
    return result;
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

  bool is_smi() { return (value_ & 1) == 0; }
  Smi* as_smi() {
    ASSERT(is_smi());
    return Smi::FromWord(value_ >> 1);
  }

  bool is_index() { return (value_ & 3) == 1; }
  word as_index() {
    ASSERT(is_index());
    return value_ >> 2;
  }

  bool is_type() { return (value_ & 3) == 3; }
  InstanceFormat::Type as_type() {
    ASSERT(is_type());
    return static_cast<InstanceFormat::Type>((value_ >> 2) & 15);
  }
  int elements() {
    ASSERT(is_type());
    return value_ >> 6;
  }

  word as_word() { return value_; }

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

void SnapshotWriter::WriteHeader(InstanceFormat::Type type, int elements = 0) {
  WriteWord(Header::FromTypeAndElements(type, elements).as_word());
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
  memory_ = ObjectMemory::AllocateChunk(program->heap()->space(), ReadWord());
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

  // Read the roots.
  ReaderVisitor visitor(this);
  program->IterateRoots(&visitor);

  program->heap()->space()->AppendProgramChunk(memory_, top_);
  backward_references_.Delete();

  // Programs read from a snapshot are always compact.
  program->set_is_compact(true);

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

  // Write the size of the heap.
  //
  // TODO(ager): This is currently platform dependent. This makes it
  // impossible to load a snapshot created on x86 on an x64 machine.
  // That seems really unfortunate. We could keep track of byte data
  // and pointers separately and record the size of pointers and the
  // size of data so that we can deserialize in a platform independent
  // way.
  WriteWord(program->heap()->space()->Used());

  // Write all the program state (except roots).
  WriteObject(program->entry());
  WriteWord(program->main_arity());
  WriteObject(program->classes());
  WriteObject(program->constants());
  WriteObject(program->static_methods());
  WriteObject(program->static_fields());

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
    case InstanceFormat::STRING_TYPE:
      String::cast(object)->StringWriteTo(this, klass);
      break;
    case InstanceFormat::ARRAY_TYPE:
      Array::cast(object)->ArrayWriteTo(this, klass);
      break;
    case InstanceFormat::BYTE_ARRAY_TYPE:
      ByteArray::cast(object)->ByteArrayWriteTo(this, klass);
      break;
    case InstanceFormat::LARGE_INTEGER_TYPE:
      LargeInteger::cast(object)->LargeIntegerWriteTo(this, klass);
      break;
    case InstanceFormat::INSTANCE_TYPE:
      Instance::cast(object)->InstanceWriteTo(this, klass);
      break;
    case InstanceFormat::CLASS_TYPE:
      Class::cast(object)->ClassWriteTo(this, klass);
      break;
    case InstanceFormat::FUNCTION_TYPE:
      Function::cast(object)->FunctionWriteTo(this, klass);
      break;
    case InstanceFormat::DOUBLE_TYPE:
      Double::cast(object)->DoubleWriteTo(this, klass);
      break;
    case InstanceFormat::INITIALIZER_TYPE:
      Initializer::cast(object)->InitializerWriteTo(this, klass);
      break;
    default:
      // Unable to handle this type of object.
      UNREACHABLE();
  }
}

List<Object*> SnapshotReader::ReadList() {
  int length = ReadWord();
  Object** data = static_cast<Object**>(malloc(kPointerSize * length));
  for (int i = 0; i < length; i++) {
    data[i] = ReadObject();
  }
  return List<Object*>(data, length);
}

void SnapshotWriter::WriteList(List<Object*> list) {
  int length = list.length();
  WriteWord(length);
  for (int i = 0; i < length; i++) {
    WriteObject(list[i]);
  }
}

List<int> SnapshotReader::ReadWordList() {
  int length = ReadWord();
  int* data = static_cast<int*>(malloc(sizeof(int) * length));
  for (int i = 0; i < length; i++) {
    data[i] = ReadWord();
  }
  return List<int>(data, length);
}

void SnapshotWriter::WriteWordList(List<int> list) {
  int length = list.length();
  WriteWord(length);
  for (int i = 0; i < length; i++) {
    WriteWord(list[i]);
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
  writer->WriteHeader(InstanceFormat::STRING_TYPE, length());
  writer->Forward(this);
  // Body.
  writer->WriteBytes(length() * sizeof(uint16_t), byte_address_for(0));
}

void String::StringReadFrom(SnapshotReader* reader, int length) {
  set_length(length);
  set_hash_value(kNoHashValue);
  reader->ReadBytes(length * sizeof(uint16_t), byte_address_for(0));
}

void Array::ArrayWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::ARRAY_TYPE, length());
  writer->Forward(this);
  // Body.
  for (int i = 0; i < length(); i++) {
    writer->WriteObject(get(i));
  }
}

void Array::ArrayReadFrom(SnapshotReader* reader, int length) {
  set_length(length);
  for (int i = 0; i < length; i++) set(i, reader->ReadObject());
}

void ByteArray::ByteArrayWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::BYTE_ARRAY_TYPE, length());
  writer->Forward(this);
  // Body.
  writer->WriteBytes(length(), byte_address_for(0));
}

void ByteArray::ByteArrayReadFrom(SnapshotReader* reader, int length) {
  set_length(length);
  reader->ReadBytes(length, byte_address_for(0));
}

void Instance::InstanceWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  int nof = klass->NumberOfInstanceFields();
  writer->WriteHeader(klass->instance_format().type(), nof);
  writer->Forward(this);
  // Body
  for (int i = 0; i < nof; i++) {
    writer->WriteObject(GetInstanceField(i));
  }
}

void Instance::InstanceReadFrom(SnapshotReader* reader, int fields) {
  int size = AllocationSize(fields);
  for (int offset = kPointerSize; offset < size; offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

void Class::ClassWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::CLASS_TYPE);
  writer->Forward(this);
  // Body.
  int size = AllocationSize();
  for (int offset = kPointerSize; offset < size; offset += kPointerSize) {
    writer->WriteObject(at(offset));
  }
}

void Class::ClassReadFrom(SnapshotReader* reader) {
  int size = AllocationSize();
  for (int offset = kPointerSize; offset < size; offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

void Function::FunctionWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  int bytecode_size = BytecodeAllocationSize(bytecode_size());
  ASSERT(literals_size() == 0);
  writer->WriteHeader(InstanceFormat::FUNCTION_TYPE, bytecode_size);
  writer->Forward(this);
  // Body.
  for (int offset = kPointerSize;
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
  for (int offset = kPointerSize;
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
  writer->WriteHeader(InstanceFormat::LARGE_INTEGER_TYPE);
  writer->Forward(this);
  // Body.
  writer->WriteInt64(value());
}

void LargeInteger::LargeIntegerReadFrom(SnapshotReader* reader) {
  set_value(reader->ReadInt64());
}

void Double::DoubleWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::DOUBLE_TYPE);
  writer->Forward(this);
  // Body.
  writer->WriteDouble(value());
}

void Double::DoubleReadFrom(SnapshotReader* reader) {
  set_value(reader->ReadDouble());
}

void Initializer::InitializerWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::INITIALIZER_TYPE);
  writer->Forward(this);
  // Body.
  for (int offset = kPointerSize;
       offset < Initializer::kSize;
       offset += kPointerSize) {
    writer->WriteObject(at(offset));
  }
}

void Initializer::InitializerReadFrom(SnapshotReader* reader) {
  for (int offset = kPointerSize;
       offset < Initializer::kSize;
       offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

}  // namespace fletch
