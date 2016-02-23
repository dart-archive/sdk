// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/snapshot.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include "src/shared/assert.h"
#include "src/shared/bytecodes.h"
#include "src/shared/utils.h"
#include "src/shared/version.h"

#include "src/vm/object.h"
#include "src/vm/program.h"

namespace dartino {

static const int kSupportedSizeOfDouble = 8;
static const int kReferenceTableSizeBytes = 4;
static const int kHeapSizeBytes = 4;

class Header {
 public:
  explicit Header(int64 value) : value_(value) {}

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
                                    int elements = 0) {
    Header h = Header(TypeField::encode(type) |
                      ElementsField::encode(elements) | kTypeAndElementsTag);
    ASSERT(h.is_type());
    ASSERT(type == h.as_type());
    ASSERT(elements == h.elements());
    return h;
  }

  // Compute the object size based on type and elements.
  int Size() {
    switch (as_type()) {
      case InstanceFormat::ONE_BYTE_STRING_TYPE:
        return OneByteString::AllocationSize(elements());
      case InstanceFormat::TWO_BYTE_STRING_TYPE:
        return TwoByteString::AllocationSize(elements());
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
        return Function::AllocationSize(
            Function::BytecodeAllocationSize(elements()));
      case InstanceFormat::DOUBLE_TYPE:
        return Double::AllocationSize();
      case InstanceFormat::INITIALIZER_TYPE:
        return Initializer::AllocationSize();
      case InstanceFormat::DISPATCH_TABLE_ENTRY_TYPE:
        return DispatchTableEntry::AllocationSize();
      default:
        UNREACHABLE();
        return 0;
    }
  }

  bool is_smi() { return (value_ & kSmiMask) == kSmiTag; }
  bool is_native_smi() { return is_smi() && Smi::IsValid(value_ >> kSmiShift); }
  Smi* as_smi() {
    ASSERT(is_native_smi());
    return Smi::FromWord(value_ >> kSmiShift);
  }

  int64 as_large_integer_value() {
    ASSERT(is_smi() && !is_native_smi());
    return value_ >> kSmiShift;
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

  word as_word() {
    ASSERT(static_cast<word>(value_) == value_);
    return value_;
  }

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
  class ElementsField : public BitField<word, 6, 26> {};

 private:
  int64 value_;
};

class ObjectInfo {
 public:
  ObjectInfo(Class* the_class, int index)
      : the_class_(the_class), index_(index) {}
  Class* the_class() { return the_class_; }
  int index() { return index_; }

 private:
  Class* the_class_;
  int index_;
};

class ReaderVisitor : public PointerVisitor {
 public:
  explicit ReaderVisitor(SnapshotReader* reader) : reader_(reader) {}

  void Visit(Object** p) { *p = reader_->ReadObject(); }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) *p = reader_->ReadObject();
  }

 private:
  SnapshotReader* reader_;
};

class WriterVisitor : public PointerVisitor {
 public:
  explicit WriterVisitor(SnapshotWriter* writer) : writer_(writer) {}

  void Visit(Object** p) { writer_->WriteObject(*p); }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) writer_->WriteObject(*p);
  }

 private:
  SnapshotWriter* writer_;
};

class UnmarkSnapshotVisitor : public PointerVisitor {
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

class UnmarkVisitor : public PointerVisitor {
 public:
  UnmarkVisitor() {}

  void Visit(Object** p) { Unmark(*p); }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) Unmark(*p);
  }

 private:
  void Unmark(Object* object) {
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

void SnapshotWriter::WriteBytes(int length, const uint8* values) {
  EnsureCapacity(length);
  memcpy(&snapshot_[position_], values, length);
  position_ += length;
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

void SnapshotWriter::WriteHeader(InstanceFormat::Type type, int elements) {
  WriteInt64(Header::FromTypeAndElements(type, elements).as_word());
}

Program* SnapshotReader::ReadProgram() {
  if (ReadByte() != 0xbe || ReadByte() != 0xef) {
    Print::Error("Error: Snapshot has wrong magic header!\n");
    Platform::Exit(-1);
  }

  const char* version = GetVersion();
  int version_length = strlen(version);
  int snapshot_version_length = ReadInt64();
  uint8* snapshot_version = new uint8[snapshot_version_length];
  ReadBytes(snapshot_version_length, snapshot_version);
  /*
  if ((version_length != snapshot_version_length) ||
      (strncmp(version, reinterpret_cast<char*>(snapshot_version),
               snapshot_version_length) != 0)) {
    delete[] snapshot_version;
    Print::Error("Error: Snapshot and VM versions do not agree.\n");
    Platform::Exit(-1);
  }
  */
  USE(version_length);
  delete[] snapshot_version;

  int hashtag = ReadInt64();

  // Read the required backward reference table size.
  int references = 0;
  for (int i = 0; i < kReferenceTableSizeBytes; i++) {
    references = (references << 8) | ReadByte();
  }

  Program* program = new Program(Program::kLoadedFromSnapshot, hashtag);

  // Read the heap size and allocate an area for it.
  int size_position;
  if (kPointerSize == 8 && sizeof(dartino_double) == 8) {
    size_position = position_ + 0 * kHeapSizeBytes;
  } else if (kPointerSize == 8 && sizeof(dartino_double) == 4) {
    size_position = position_ + 1 * kHeapSizeBytes;
  } else if (kPointerSize == 4 && sizeof(dartino_double) == 8) {
    size_position = position_ + 2 * kHeapSizeBytes;
  } else {
    ASSERT(kPointerSize == 4 && sizeof(dartino_double) == 4);
    size_position = position_ + 3 * kHeapSizeBytes;
  }
  position_ += 4 * kHeapSizeBytes;
  int heap_size = ReadHeapSizeFrom(size_position);
  // Make sure to make room for the filler at the end of the program space.
  memory_ =
      ObjectMemory::AllocateChunk(program->heap()->space(), heap_size + 1);
  top_ = memory_->base();

  // Allocate space for the backward references.
  backward_references_ = List<HeapObject*>::New(references);

  // Read the roots.
  ReaderVisitor visitor(this);
  program->IterateRootsIgnoringSession(&visitor);

  // Read all the program state (except roots).
  program->set_entry(Function::cast(ReadObject()));
  program->set_static_fields(Array::cast(ReadObject()));
  program->set_dispatch_table(Array::cast(ReadObject()));

  program->heap()->space()->Append(memory_);
  program->heap()->space()->UpdateBaseAndLimit(memory_, top_);
  backward_references_.Delete();

  // Programs read from a snapshot are always compact.
  program->SetupDispatchTableIntrinsics();

  // As a sanity check we ensure that the heap size the writer of the snapshot
  // predicted we would have, is in fact *precisely* how much space we needed.
  int consumed_memory = top_ - memory_->base();
  if (consumed_memory != heap_size) {
    FATAL("The heap size in the snapshot was incorrect.");
  }

  return program;
}

List<uint8> SnapshotWriter::WriteProgram(Program* program) {
  ASSERT(program->is_optimized());

  program->ClearDispatchTableIntrinsics();

  // Emit recognizable header.
  WriteByte(0xbe);
  WriteByte(0xef);

  // Emit version of the VM.
  const char* version = GetVersion();
  int version_length = strlen(version);
  WriteInt64(version_length);
  WriteBytes(version_length, reinterpret_cast<const uint8*>(version));

  // Emit a tag that can be used to match profiler ticks with a program.
  int hashtag = 0xcafe + (Platform::GetMicroseconds() % 0x10000);
  program->set_hashtag(hashtag);
  WriteInt64(hashtag);

  // Reserve space for the backward reference table size.
  int reference_count_position = position_;
  for (int i = 0; i < kReferenceTableSizeBytes; i++) WriteByte(0);

  // Reserve space for the size of the heap.
  int size64_double_position = position_ + 0 * kHeapSizeBytes;
  int size64_float_position = position_ + 1 * kHeapSizeBytes;
  int size32_double_position = position_ + 2 * kHeapSizeBytes;
  int size32_float_position = position_ + 3 * kHeapSizeBytes;
  for (int i = 0; i < 4 * kHeapSizeBytes; i++) WriteByte(0);

  // Write out all the roots of the program.
  WriterVisitor visitor(this);
  program->IterateRootsIgnoringSession(&visitor);

  // Write all the program state (except roots).
  WriteObject(program->entry());
  WriteObject(program->static_fields());
  WriteObject(program->dispatch_table());

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
  WriteHeapSizeTo(size64_double_position, heap_size_.offset_64bits_double);
  WriteHeapSizeTo(size64_float_position, heap_size_.offset_64bits_float);
  WriteHeapSizeTo(size32_double_position, heap_size_.offset_32bits_double);
  WriteHeapSizeTo(size32_float_position, heap_size_.offset_32bits_float);

  return snapshot_.Sublist(0, position_);
}

Object* SnapshotReader::ReadObject() {
  Header header(ReadInt64());
  if (header.is_smi()) {
    if (header.is_native_smi()) {
      // The header word indicates that this is an encoded small integer.
      return header.as_smi();
    }

    // The smi-tagged word doesn't fit on this platform.
    ASSERT(large_integer_class_ != NULL);
    HeapObject* object = Allocate(LargeInteger::AllocationSize());
    LargeInteger* integer = reinterpret_cast<LargeInteger*>(object);
    integer->set_class(large_integer_class_);
    integer->set_value(header.as_large_integer_value());
    return object;
  } else if (header.is_index()) {
    // The header word indicates that this is a backreference.
    word index = header.as_index();
    ASSERT(index < 0);
    return Dereference(-index);
  }

  int elements = header.elements();
  InstanceFormat::Type type = header.as_type();

  int size = header.Size();
  if (type == InstanceFormat::FUNCTION_TYPE) {
    size += ReadInt64() * kPointerSize;
  }
  HeapObject* object = Allocate(size);

  AddReference(object);
  object->set_class(reinterpret_cast<Class*>(ReadObject()));
  switch (type) {
    case InstanceFormat::ONE_BYTE_STRING_TYPE:
      reinterpret_cast<OneByteString*>(object)
          ->OneByteStringReadFrom(this, elements);
      break;
    case InstanceFormat::TWO_BYTE_STRING_TYPE:
      reinterpret_cast<TwoByteString*>(object)
          ->TwoByteStringReadFrom(this, elements);
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
    case InstanceFormat::CLASS_TYPE: {
      reinterpret_cast<Class*>(object)->ClassReadFrom(this);
      Class* klass = reinterpret_cast<Class*>(object);
      if (klass->instance_format().type() ==
          InstanceFormat::LARGE_INTEGER_TYPE) {
        large_integer_class_ = klass;
      }
      break;
    }
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
    case InstanceFormat::DISPATCH_TABLE_ENTRY_TYPE: {
      DispatchTableEntry* entry = reinterpret_cast<DispatchTableEntry*>(object);
      entry->DispatchTableEntryReadFrom(this);
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
    Smi* smi = Smi::cast(object);
    if (!Smi::IsValidAsPortable(smi->value())) {
      int integer_size =
          LargeInteger::CalculatePortableSize().ComputeSizeInBytes(4, -1);
      heap_size_.offset_32bits_double += integer_size;
      heap_size_.offset_32bits_float += integer_size;
    }
    WriteInt64(Header::FromSmi(smi).as_word());
    return;
  }

  HeapObject* heap_object = HeapObject::cast(object);
  // Then check possible backward reference.
  word f = heap_object->forwarding_word();
  if (f != 0) {
    ObjectInfo* info = reinterpret_cast<ObjectInfo*>(f);
    WriteInt64(Header::FromIndex(-info->index()).as_word());
    return;
  }

  Class* klass = ClassFor(heap_object);
  InstanceFormat::Type type = klass->instance_format().type();

  // Serialize the object.
  switch (type) {
    case InstanceFormat::ONE_BYTE_STRING_TYPE: {
      OneByteString* str = OneByteString::cast(object);
      heap_size_ += str->CalculatePortableSize();
      str->OneByteStringWriteTo(this, klass);
      break;
    }
    case InstanceFormat::TWO_BYTE_STRING_TYPE: {
      TwoByteString* str = TwoByteString::cast(object);
      heap_size_ += str->CalculatePortableSize();
      str->TwoByteStringWriteTo(this, klass);
      break;
    }
    case InstanceFormat::ARRAY_TYPE: {
      Array* array = Array::cast(object);
      heap_size_ += array->CalculatePortableSize();
      array->ArrayWriteTo(this, klass);
      break;
    }
    case InstanceFormat::BYTE_ARRAY_TYPE: {
      ByteArray* array = ByteArray::cast(object);
      heap_size_ += array->CalculatePortableSize();
      array->ByteArrayWriteTo(this, klass);
      break;
    }
    case InstanceFormat::LARGE_INTEGER_TYPE: {
      LargeInteger* integer = LargeInteger::cast(object);
      heap_size_ += integer->CalculatePortableSize();
      integer->LargeIntegerWriteTo(this, klass);
      break;
    }
    case InstanceFormat::INSTANCE_TYPE: {
      Instance* instance = Instance::cast(object);
      heap_size_ += instance->CalculatePortableSize(klass);
      instance->InstanceWriteTo(this, klass);
      break;
    }
    case InstanceFormat::CLASS_TYPE: {
      Class* klass = Class::cast(object);
      (*class_offsets_)[klass] = PortableOffset(heap_size_);
      heap_size_ += klass->CalculatePortableSize();
      klass->ClassWriteTo(this, klass);
      break;
    }
    case InstanceFormat::FUNCTION_TYPE: {
      Function* function = Function::cast(object);
      (*function_offsets_)[function] = PortableOffset(heap_size_);
      heap_size_ += function->CalculatePortableSize();
      function->FunctionWriteTo(this, klass);
      break;
    }
    case InstanceFormat::DOUBLE_TYPE: {
      Double* d = Double::cast(object);
      heap_size_ += d->CalculatePortableSize();
      d->DoubleWriteTo(this, klass);
      break;
    }
    case InstanceFormat::INITIALIZER_TYPE: {
      Initializer* initializer = Initializer::cast(object);
      heap_size_ += initializer->CalculatePortableSize();
      initializer->InitializerWriteTo(this, klass);
      break;
    }
    case InstanceFormat::DISPATCH_TABLE_ENTRY_TYPE: {
      DispatchTableEntry* entry = DispatchTableEntry::cast(object);
      heap_size_ += entry->CalculatePortableSize();
      entry->DispatchTableEntryWriteTo(this, klass);
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

void OneByteString::OneByteStringWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::ONE_BYTE_STRING_TYPE, length());
  writer->Forward(this);
  // Body.
  writer->WriteBytes(length(), byte_address_for(0));
}

void OneByteString::OneByteStringReadFrom(SnapshotReader* reader, int length) {
  set_length(length);
  set_hash_value(kNoHashValue);
  reader->ReadBytes(length, byte_address_for(0));
}

void TwoByteString::TwoByteStringWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::TWO_BYTE_STRING_TYPE, length());
  writer->Forward(this);
  // Body.
  writer->WriteBytes(length() * sizeof(uint16_t), byte_address_for(0));
}

void TwoByteString::TwoByteStringReadFrom(SnapshotReader* reader, int length) {
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
  if (length() == 0) return;
  writer->WriteBytes(length(), byte_address_for(0));
}

void ByteArray::ByteArrayReadFrom(SnapshotReader* reader, int length) {
  set_length(length);
  if (length == 0) return;
  reader->ReadBytes(length, byte_address_for(0));
}

void Instance::InstanceWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  int nof = klass->NumberOfInstanceFields();
  writer->WriteHeader(klass->instance_format().type(), nof);
  writer->Forward(this);
  // Body
  writer->WriteInt64(FlagsBits());
  for (int i = 0; i < nof; i++) {
    writer->WriteObject(GetInstanceField(i));
  }
}

void Instance::InstanceReadFrom(SnapshotReader* reader, int fields) {
  int size = AllocationSize(fields);
  SetFlagsBits(reader->ReadInt64());
  for (int offset = Instance::kSize; offset < size; offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

void Class::ClassWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::CLASS_TYPE);
  writer->Forward(this);
  // Body.
  int size = AllocationSize();
  for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
    writer->WriteObject(at(offset));
  }
}

void Class::ClassReadFrom(SnapshotReader* reader) {
  int size = AllocationSize();
  for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

#ifdef DARTINO_TARGET_X64
void Function::WriteByteCodes(SnapshotWriter* writer) {
  ASSERT(kPointerSize == 8);
  uint8* bcp = bytecode_address_for(0);
  int i = 0;
  while (i < bytecode_size()) {
    Opcode opcode = static_cast<Opcode>(bcp[i]);
    switch (opcode) {
      case kLoadConst:
      case kAllocate:
      case kAllocateImmutable:
      case kInvokeStatic:
      case kInvokeFactory: {
        ASSERT(Bytecode::Size(opcode) == 5);
        // Read the offset.
        int32 offset = Utils::ReadInt32(bcp + i + 1);
        // Rewrite offset from 64 bit format to 32 bit format.
        int delta_to_bytecode_end = bytecode_size() - i;
        int padding32 = Utils::RoundUp(bytecode_size(), 4) - bytecode_size();
        int padding64 =
            Utils::RoundUp(bytecode_size(), kPointerSize) - bytecode_size();
        int pointers =
            (offset - delta_to_bytecode_end - padding64) / kPointerSize;
        offset = delta_to_bytecode_end + padding32 + pointers * 4;
        // Write the bytecode.
        writer->WriteByte(bcp[i++]);
        uint8* offset_pointer = reinterpret_cast<uint8*>(&offset);
        for (int j = 0; j < 4; j++) {
          writer->WriteByte(*(offset_pointer++));
        }
        i += 4;
        break;
      }
      case kMethodEnd:
        // Write the method end bytecode and everything that follows.
        writer->WriteBytes(bytecode_size() - i, bcp + i);
        return;
      default:
        // TODO(ager): Maybe just collect chunks and copy them with
        // memcpy when encountering the end or a bytecode we need to
        // rewrite?
        for (int j = 0; j < Bytecode::Size(opcode); j++) {
          writer->WriteByte(bcp[i++]);
        }
        break;
    }
  }
}
#else
void Function::WriteByteCodes(SnapshotWriter* writer) {
  ASSERT(kPointerSize == 4);
  writer->WriteBytes(bytecode_size(), bytecode_address_for(0));
}
#endif

#ifdef DARTINO_TARGET_X64
void Function::ReadByteCodes(SnapshotReader* reader) {
  ASSERT(kPointerSize == 8);
  uint8* bcp = bytecode_address_for(0);
  int i = 0;
  while (i < bytecode_size()) {
    uint8 raw_opcode = reader->ReadByte();
    Opcode opcode = static_cast<Opcode>(raw_opcode);
    switch (opcode) {
      case kLoadConst:
      case kAllocate:
      case kAllocateImmutable:
      case kInvokeStatic:
      case kInvokeFactory: {
        ASSERT(Bytecode::Size(opcode) == 5);
        // Read the offset.
        int32 offset = 0;
        uint8* offset_pointer = reinterpret_cast<uint8*>(&offset);
        for (int i = 0; i < 4; i++) {
          offset_pointer[i] = reader->ReadByte();
        }
        // Rewrite offset from 32 bit format to 64 bit format.
        int delta_to_bytecode_end = bytecode_size() - i;
        int padding32 = Utils::RoundUp(bytecode_size(), 4) - bytecode_size();
        int padding64 =
            Utils::RoundUp(bytecode_size(), kPointerSize) - bytecode_size();
        int pointers = (offset - delta_to_bytecode_end - padding32) / 4;
        offset = delta_to_bytecode_end + padding64 + pointers * kPointerSize;
        // Write the bytecode.
        bcp[i++] = raw_opcode;
        Utils::WriteInt32(bcp + i, offset);
        i += 4;
        break;
      }
      case kMethodEnd:
        // Read the method end bytecode and everything that follows.
        bcp[i++] = raw_opcode;
        while (i < bytecode_size()) {
          bcp[i++] = reader->ReadByte();
        }
        return;
      default:
        // TODO(ager): Maybe just collect chunks and copy them with
        // memcpy when encountering the end or a bytecode we need to
        // rewrite?
        bcp[i++] = raw_opcode;
        for (int j = 1; j < Bytecode::Size(opcode); j++) {
          bcp[i++] = reader->ReadByte();
        }
        break;
    }
  }
}
#else
void Function::ReadByteCodes(SnapshotReader* reader) {
  reader->ReadBytes(bytecode_size(), bytecode_address_for(0));
}
#endif

void Function::FunctionWriteTo(SnapshotWriter* writer, Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::FUNCTION_TYPE, bytecode_size());
  writer->WriteInt64(literals_size());
  writer->Forward(this);
  // Body.
  for (int offset = HeapObject::kSize; offset < Function::kSize;
       offset += kPointerSize) {
    writer->WriteObject(at(offset));
  }
  WriteByteCodes(writer);
  for (int i = 0; i < literals_size(); i++) {
    writer->WriteObject(literal_at(i));
  }
}

void Function::FunctionReadFrom(SnapshotReader* reader, int length) {
  for (int offset = HeapObject::kSize; offset < Function::kSize;
       offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
  ReadByteCodes(reader);
  for (int i = 0; i < literals_size(); i++) {
    set_literal_at(i, reader->ReadObject());
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
  for (int offset = HeapObject::kSize; offset < Initializer::kSize;
       offset += kPointerSize) {
    writer->WriteObject(at(offset));
  }
}

void Initializer::InitializerReadFrom(SnapshotReader* reader) {
  for (int offset = HeapObject::kSize; offset < Initializer::kSize;
       offset += kPointerSize) {
    at_put(offset, reader->ReadObject());
  }
}

void DispatchTableEntry::DispatchTableEntryWriteTo(SnapshotWriter* writer,
                                                   Class* klass) {
  // Header.
  writer->WriteHeader(InstanceFormat::DISPATCH_TABLE_ENTRY_TYPE);
  writer->Forward(this);

  // Body.
  writer->WriteObject(at(kTargetOffset));
  ASSERT(code() == NULL);
  writer->WriteObject(offset());
  writer->WriteInt64(selector());
}

void DispatchTableEntry::DispatchTableEntryReadFrom(SnapshotReader* reader) {
  set_target(Function::cast(reader->ReadObject()));
  set_code(NULL);
  set_offset(Smi::cast(reader->ReadObject()));
  set_selector(reader->ReadInt64());
}

}  // namespace dartino
