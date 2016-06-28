// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
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

class SnapshotOracle;

void FixByteCodes(uint8* bcp, uword size, int old_shift, int new_shift);

class ReaderVisitor : public PointerVisitor {
 public:
  explicit ReaderVisitor(SnapshotReader* reader) : reader_(reader) {}

  void Visit(Object** p) {
    *p = reinterpret_cast<Object*>(reader_->ReadWord());
  }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++)
      *p = reinterpret_cast<Object*>(reader_->ReadWord());
  }

 private:
  SnapshotReader* reader_;
};

void SnapshotWriter::WriteByte(uint8 value) {
  EnsureCapacity(1);
  snapshot_[position_++] = value;
}

void SnapshotWriter::WriteSize(unsigned value) {
  EnsureCapacity(4);
  snapshot_[position_++] = value & 0xff;
  snapshot_[position_++] = (value >> 8) & 0xff;
  snapshot_[position_++] = (value >> 16) & 0xff;
  snapshot_[position_++] = (value >> 24) & 0xff;
}

double SnapshotReader::ReadDouble() {
  double result = 0.0;
  uint8* p_data = reinterpret_cast<uint8*>(&result);
  ReadBytes(8, p_data);
  return result;
}

void SnapshotWriter::WriteDouble(double value) {
  union {
    double d;
    uint8 bytes[8];
  } u;
  u.d = value;
  EnsureCapacity(8);
  for (int i = 0; i < 8; i++) {
    snapshot_[position_++] = u.bytes[i];
  }
}

void SnapshotReader::ReadBytes(int length, uint8* values) {
  memcpy(values, &snapshot_[position_], length);
  position_ += length;
}

void SnapshotWriter::WriteBytes(const uint8* values, int length) {
  EnsureCapacity(length);
  memcpy(&snapshot_[position_], values, length);
  position_ += length;
}

unsigned SnapshotReader::ReadSize() {
  unsigned size = ReadByte();
  size += ReadByte() << 8;
  size += ReadByte() << 16;
  size += ReadByte() << 24;
  return size;
}

void SnapshotReader::ReadSectionBoundary() {
  uint8 boundary = ReadByte();
  ASSERT(IsSectionBoundary(boundary));
}

uint32_t ComputeSnapshotHash(List<uint8> snapshot) {
  return Utils::StringHash(reinterpret_cast<const uint8*>(snapshot.data()),
                           snapshot.length(), 1);
}

const char* OpCodeName(int opcode) {
  switch (opcode) {
    case kSnapshotPopular:
    case kSnapshotPopular + 1:
      return "kSnapshotPopular";
    case kSnapshotRecentPointer:
      return "kSnapshotRecentPointer REL0";
    case kSnapshotRecentPointer + 1:
      return "kSnapshotRecentPointer REL1";
    case kSnapshotRecentSmi:
      return "kSnapshotRecentSmi";
    case kSnapshotSmi:
      return "kSnapshotSmi";
    case kSnapshotExternal:
      return "kSnapshotExternal";
    case kSnapshotRaw:
      return "kSnapshotRaw";
  }
  return "UNKNOWN";
}

#ifdef DARTINO_TARGET_X64
struct RootCounter : public PointerVisitor {
  virtual void VisitBlock(Object** from, Object** to) { count += to - from; }
  int count = 0;
};

int SnapshotReader::Skip(int position, int words_to_skip) {
  ASSERT(IsSectionBoundary(snapshot_[position]));
  position++;
  while (words_to_skip-- != 0) {
    uint8 byte_code = snapshot_[position++];
    ASSERT(OpCode(byte_code) != kSnapshotRaw);
    if (IsOneBytePopularByteCode(byte_code)) continue;
    position += ArgumentBytes(byte_code);
  }
  return position;
}

void SnapshotReader::BuildLocationMap(Program* program, word total_floats,
                                      uword heap_size) {
  // On 64 bit platforms we prescan the entire snapshot to build up a map from
  // ideal addresses to real addresses.  This is obviously rather expensive and
  // precludes a truly streamed snapshot, but we expect 64 bit platforms to be
  // so beefy that it doesn't matter.
  int position = position_;
  position = Skip(position, kSnapshotNumberOfPopularObjects);

  RootCounter roots;
  program->IterateRootsIgnoringSession(&roots);
  position = Skip(position, roots.count);

  ASSERT(IsSectionBoundary(snapshot_[position]));
  position++;

  uword real_address = base_ - total_floats * Double::kSize;
  uword end = real_address + heap_size;
  word ideal_address = -total_floats * kIdealBoxedFloatSize;
  for (int i = 0; i < total_floats; i++) {
    location_map_[ideal_address] = real_address;
    real_address += Double::kSize;
    ideal_address += kIdealBoxedFloatSize;
  }
  ASSERT(ideal_address == 0);
  ASSERT(real_address == base_);
  position += total_floats * sizeof(double);
  while (real_address < end) {
    uint8 b = snapshot_[position++];
    if (IsSectionBoundary(b)) continue;
    int opcode = OpCode(b);
    int w;  // Width - number of extra bytes in the instruction.
    switch (opcode) {
      case kSnapshotPopular:
      case kSnapshotPopular + 1:
        w = 0;
        break;
      case kSnapshotRecentPointer:
      case kSnapshotRecentPointer + 1:
      case kSnapshotRecentSmi:
      case kSnapshotSmi:
      case kSnapshotExternal:
      case kSnapshotRaw:
        w = ArgumentBytes(b);
        break;
      default:
        UNREACHABLE();
    }

    switch (opcode) {
      case kSnapshotPopular:
      case kSnapshotPopular + 1:
      case kSnapshotRecentPointer:
      case kSnapshotRecentPointer + 1:
        // We only need map entries for the start of objects and objects can
        // only start with certain bytecodes.
        location_map_[ideal_address] = real_address;
      // FALL THROUGH!
      case kSnapshotRecentSmi:
      case kSnapshotSmi:
      case kSnapshotExternal: {
        position += w;
        real_address += kWordSize;
        ideal_address += kIdealWordSize;
        break;
      }
      case kSnapshotRaw: {
        word x = ArgumentStart(b, w);
        while (w-- != 0) {
          x <<= 8;
          x |= snapshot_[position++];
        }
        real_address += Utils::RoundUp(x, kWordSize);
        ideal_address += Utils::RoundUp(x, kIdealWordSize);
        position += x;
        break;
      }
      default:
        UNREACHABLE();
    }
  }
  ASSERT(IsSectionBoundary(snapshot_[position]));
}

class ByteCodeFixer : public PointerVisitor {
 public:
  virtual void VisitByteCodes(uint8* bcp, uword size) {
    const int kIdealWordShift = 2;
    const int kWordShift = 3;
    ASSERT(kWordSize == 1 << kWordShift);
    ASSERT(kIdealWordSize == 1 << kIdealWordShift);
    FixByteCodes(bcp, size, kIdealWordShift, kWordShift);
  }
  virtual void VisitBlock(Object**, Object**) {}
};

class ByteCodeFixingObjectVisitor : public HeapObjectVisitor {
 public:
  virtual uword Visit(HeapObject* object) {
    if (object->IsFunction()) {
      ByteCodeFixer fixer;
      object->IterateEverything(&fixer);
    }
    return object->Size();
  }
};

#else

void SnapshotReader::BuildLocationMap(Program* program, word total_floats,
                                      uword heap_size) {}
#endif

Program* SnapshotReader::ReadProgram() {
  if (ReadByte() != 0xbe || ReadByte() != 0xef) {
    Print::Error("Error: Snapshot has wrong magic header!\n");
    Platform::Exit(-1);
  }

  const char* version = GetVersion();
  int version_length = strlen(version);
  int snapshot_version_length = ReadSize();
  {
    uint8* snapshot_version = new uint8[snapshot_version_length];
    ReadBytes(snapshot_version_length, snapshot_version);
    if (!Version::Check(version, version_length,
                        reinterpret_cast<const char*>(snapshot_version),
                        snapshot_version_length, Version::kCompatible)) {
      delete[] snapshot_version;
      Print::Error("Error: Snapshot and VM versions do not agree.\n");
      Platform::Exit(-1);
    }
    delete[] snapshot_version;
  }

  // TODO(erikcorry): This reads the entire snapshot and then rewinds,
  // which will make it hard to stream the snapshot.
  uint32_t snapshot_hash = ComputeSnapshotHash(snapshot_);

  Program* program = new Program(Program::kLoadedFromSnapshot, snapshot_hash);

// Pick the right size for our architecture.
#ifdef DARTINO64
  const int index = (sizeof(dartino_double) == 4) ? 0 : 1;
#else
  const int index = (sizeof(dartino_double) == 4) ? 2 : 3;
#endif

  uword total_floats = ReadSize();
  uword sizes[4];
  for (int i = 0; i < 4; i++) sizes[i] = ReadSize();
  uword heap_size = sizes[index];

  // Make sure to make room for the filler at the end of the program space.
  Chunk* memory = ObjectMemory::AllocateChunk(program->heap()->space(),
                                              heap_size + kWordSize);
  program->heap()->space()->Append(memory);

  base_ = memory->start() + Double::kSize * total_floats;

#ifdef DARTINO64
  recents_[0] = recents_[1] = 0;
#else
  recents_[0] = recents_[1] = base_ + HeapObject::kTag;
#endif

  int pos = position_;
  BuildLocationMap(program, total_floats, heap_size);  // 64 bit only.
  ASSERT(pos == position_);

  // Read the list of popular objects.
  ReadSectionBoundary();
  ReaderVisitor visitor(this);
  for (int i = 0; i < kSnapshotNumberOfPopularObjects; i++) {
    visitor.Visit(&popular_objects_[i]);
  }

  // Read the roots.
  ReadSectionBoundary();
  program->IterateRootsIgnoringSession(&visitor);

  // Read the main heap, starting with the boxed double objects.
  ReadSectionBoundary();
  uword double_position = memory->start();
  uword double_class = base_ + HeapObject::kTag;
  for (uword i = 0; i < total_floats; i++) {
    *reinterpret_cast<uword*>(double_position) = double_class;
    double_position += kWordSize;
    double d = ReadDouble();
    *reinterpret_cast<dartino_double*>(double_position) = d;
    double_position += sizeof(dartino_double);
  }
  ASSERT(double_position = base_);
  Object** p = reinterpret_cast<Object**>(base_);
  Object** end = reinterpret_cast<Object**>(memory->start() + heap_size);
  visitor.VisitBlock(p, end);
  ReadSectionBoundary();
  program->heap()->space()->UpdateBaseAndLimit(memory,
                                               reinterpret_cast<uword>(end));
#ifdef DARTINO64
  // This modifies byte codes in place, so we can't currenly unpack the
  // heap in a streaming way on 64 bit.
  ByteCodeFixingObjectVisitor byte_code_fixer;
  program->heap()->IterateObjects(&byte_code_fixer);
#endif

  return program;
}

class PortableSizeCalculator : public PointerVisitor {
 public:
  virtual void VisitClass(Object**) { size_ += PortableSize::Pointer(); }

  virtual void Visit(Object**) { size_ += PortableSize::Pointer(); }

  virtual void VisitBlock(Object** start, Object** end) {
    size_ += PortableSize::Pointer(end - start);
  }

  virtual void VisitInteger(uword slot) { size_ += PortableSize::Pointer(); }

  virtual void VisitLiteralInteger(int32 i) {
    size_ += PortableSize::Pointer();
  }

  virtual void VisitCode(uword slot) { size_ += PortableSize::Pointer(); }

  virtual void VisitRaw(uint8* start, uword size) {
    size_ += PortableSize::Fixed(size);
  }

  virtual void VisitByteCodes(uint8* start, uword size) {
    size_ += PortableSize::Fixed(size);
  }

  virtual void VisitFloat(dartino_double value) {
    size_ += PortableSize::Float();
  }

  PortableSize size() { return size_; }

 private:
  PortableSize size_ = PortableSize();
};

word SnapshotReader::ReadWord() {
  if (raw_to_do_ > 0) {
    word result = 0;
    ReadBytes(raw_to_do_ >= kWordSize ? kWordSize : raw_to_do_,
              reinterpret_cast<uint8*>(&result));
    raw_to_do_ -= kWordSize;
    return result;
  }
  uint8 b = ReadByte();
  if ((b & kSnapshotPopularMask) == kSnapshotPopular) {
    return reinterpret_cast<word>(popular_objects_[b]);
  } else {
    uint8 opcode = OpCode(b);
    int w = ArgumentBytes(b);
    word x = ArgumentStart(b, w);
    for (int i = 0; i < w; i++) {
      x <<= 8;
      x |= ReadByte();
    }
    if (opcode <= kSnapshotRecentSmi) {
      int index = opcode - kSnapshotRecentPointer;
      ASSERT(index >= 0 && index <= 2);
      word ideal = recents_[index];
      // For the pointers, multiply by 4.
      int pointer_flag = ((~opcode) & 4) >> 1;
      ASSERT(pointer_flag == 0 || (1 << pointer_flag) == kIdealWordSize);
      x <<= pointer_flag;
      ideal += x;
      uword actual = ideal;
#ifdef DARTINO64
      if (opcode != kSnapshotRecentSmi) {
        actual = location_map_.At(ideal) + HeapObject::kTag;
      }
#else
      if (sizeof(dartino_double) != kIdealFloatSize) {
        // Negative offsets are to Double objects, and we have to adjust the
        // actual value written back to account for non-ideal boxed float
        // sizes.  This code should be removed by the compiler on the smallest
        // devices.
        if (opcode != kSnapshotRecentSmi && actual < base_) {
          word ideal_distance = base_ - (actual - HeapObject::kTag);
          ASSERT(Double::kSize == 12 && kIdealBoxedFloatSize == 8);
          // Distance multiplied by 12/8 ie 1.5.
          actual = base_ + HeapObject::kTag -
                   (ideal_distance + (ideal_distance >> 1));
        }
      }
#endif
      recents_[index] = ideal;
      return actual;
    } else if (opcode == kSnapshotSmi) {
      return x;
    } else if (opcode == kSnapshotExternal) {
      return intrinsics_table_[x];
    } else {
      ASSERT(opcode == kSnapshotRaw);
      ASSERT(x > 0);
      raw_to_do_ = x;
      return ReadWord();
    }
  }
}

word SnapshotReader::intrinsics_table_[] = {
    reinterpret_cast<word>(InterpreterMethodEntry),
#define V(name) reinterpret_cast<word>(Intrinsic_##name),
    INTRINSICS_DO(V)
#undef V
};

// Determines for each object what its address would be in various scenarios.
// The system can be either 32 or 64 bit, and have either 32 or 64 bit floating
// point numbers.
class PortableAddressMap : public HeapObjectVisitor {
 public:
  PortableAddressMap(FunctionOffsetsType* function_offsets,
                     ClassOffsetsType* class_offsets)
      : function_offsets_(function_offsets), class_offsets_(class_offsets) {}

  virtual uword Visit(HeapObject* object) {
    ASSERT(!object->IsStack());
    int size = object->Size();
    if (object->IsDouble()) {
      ASSERT(!non_double_seen_);
    } else {
      if (!non_double_seen_) {
        first_non_double_ = portable_address_;
        non_double_seen_ = true;
      }
      if (object->IsFunction()) {
        Function* function = Function::cast(object);
        (*function_offsets_)[function] = portable_address_;
      } else if (object->IsClass()) {
        Class* clazz = Class::cast(object);
        (*class_offsets_)[clazz] = portable_address_;
      }
    }
    PortableSizeCalculator calculator;
    object->IterateEverything(&calculator);
#ifdef DARTINO32
    ASSERT(object->IsDouble() ||
           object->Size() == calculator.size().IdealizedSize());
#endif
    map_[object->address()] = portable_address_;
    portable_address_ += calculator.size();
    return size;
  }

  uword doubles_size() { return first_non_double_.IdealizedSize(); }
  uword total_floats() {
    return first_non_double_.IdealizedSize() / kIdealBoxedFloatSize;
  }

  PortableSize total_size() { return portable_address_; }

  uword IdealizedAddress(Object* object) {
    ASSERT(object->IsHeapObject());
    return map_[HeapObject::cast(object)->address()].IdealizedSize();
  }

  PortableSize PortableAddress(Object* object) {
    ASSERT(object->IsHeapObject());
    return map_[HeapObject::cast(object)->address()];
  }

 private:
  typedef HashMap<uword, PortableSize> AddrMap;

  FunctionOffsetsType* function_offsets_;
  ClassOffsetsType* class_offsets_;
  bool non_double_seen_ = false;
  PortableSize portable_address_ = PortableSize();
  PortableSize first_non_double_ = PortableSize();
  AddrMap map_;
};

// Byte codes contain relative pointers from the instruction to a word-aligned
// constant in a block that follows the byte code. Since they are word aligned,
// the offsets have to be adjusted when we convert from 32 bit to 64 bit byte
// codes or vice versa.
void FixByteCodes(uint8* bcp, uword size, int old_shift, int new_shift) {
  unsigned i = 0;
  uword old_mask = (1 << old_shift) - 1;
  uword new_mask = (1 << new_shift) - 1;
  // Round up.
  uword first_pointer_old = (size + old_mask) & ~old_mask;
  uword first_pointer_new = (size + new_mask) & ~new_mask;
  while (i < size) {
    Opcode opcode = static_cast<Opcode>(bcp[i]);
    switch (opcode) {
      case kLoadConst:
      case kAllocate:
      case kAllocateImmutable:
      case kInvokeStatic:
      case kInvokeFactory: {
        ASSERT(Bytecode::Size(opcode) == 5);
        // Read the offset.
        unsigned offset = Utils::ReadInt32(bcp + i + 1);
        // Rewrite offset from 64 bit format to 32 bit format.
        unsigned offset_from_start = i + offset;
        unsigned pointers =
            (offset_from_start - first_pointer_old) >> old_shift;
        unsigned new_offset_from_start =
            first_pointer_new + (pointers << new_shift);
        unsigned new_offset = new_offset_from_start - i;

        uint8* offset_pointer = reinterpret_cast<uint8*>(&new_offset);
        for (int j = 0; j < 4; j++) {
          bcp[i + j + 1] = offset_pointer[j];
        }
        i += 5;
        break;
      }
      case kMethodEnd:
        return;
      default:
        i += Bytecode::Size(opcode);
        break;
    }
  }
}

class ObjectWriter : public PointerVisitor {
 public:
  ObjectWriter(SnapshotWriter* writer, PortableAddressMap* map,
               SnapshotOracle* pointer_oracle, SnapshotOracle* smi_oracle,
               HeapObject* current = NULL)
      : writer_(writer),
        address_map_(map),
        pointer_oracle_(pointer_oracle),
        smi_oracle_(smi_oracle),
        current_(current == NULL ? 0 : reinterpret_cast<uint8*>(
                                           current->address())) {}

  virtual void VisitClass(Object** p) {
    ASSERT(current_ == reinterpret_cast<uint8*>(p));
    ASSERT(!(*p)->IsSmi());
    WriteWord(*p);
    current_ += kWordSize;
  }

  void VisitBlock(Object** start, Object** end) {
    if (start == end) return;
    uint8* block_start = reinterpret_cast<uint8*>(start);
    ASSERT(current_ == 0 || block_start == current_);
    for (Object** p = start; p < end; p++) {
      WriteWord(*p);
    }
    if (current_ != NULL) current_ = reinterpret_cast<uint8*>(end);
  }

  void End(uword end_of_object) {
    ASSERT(current_ == reinterpret_cast<uint8*>(end_of_object));
  }

  virtual void VisitInteger(uword slot) {
    ASSERT(current_ = reinterpret_cast<uint8*>(slot));
    WriteInteger(*reinterpret_cast<uword*>(slot));
    current_ += kWordSize;
  }

  virtual void VisitLiteralInteger(int32 i) {
    WriteInteger(i);
    current_ += kWordSize;
  }

  virtual void VisitCode(uword slot) {
    ASSERT(current_ = reinterpret_cast<uint8*>(slot));
    void* code = *reinterpret_cast<void**>(slot);
    // In the snapshot format the external pointers are pointers to intrinsic
    // code.  The intrinsics are numbered starting from 1. The 0th intrinsic is
    // the address of the interpreter, corresponding to interpreted methods.
    int intrinsic = 0;
    int i = 0;
#define V(name)                                            \
  i++;                                                     \
  if (code == reinterpret_cast<void*>(Intrinsic_##name)) { \
    intrinsic = i;                                         \
  }
    INTRINSICS_DO(V)
#undef V
    if (intrinsic == 0) {
      void* method_entry = reinterpret_cast<void*>(InterpreterMethodEntry);
      ASSERT(code == method_entry);
    }
    WriteOpcode(kSnapshotExternal, intrinsic);
    current_ += kWordSize;
  }

  virtual void VisitByteCodes(uint8* bcp, uword size) {
    ASSERT(bcp == current_);
#ifdef DARTINO64
    uint8* bcp32 = new uint8[size];
    memcpy(bcp32, bcp, size);
    const int kIdealWordShift = 2;
    const int kWordShift = 3;
    ASSERT(kWordSize == 1 << kWordShift);
    ASSERT(kIdealWordSize == 1 << kIdealWordShift);
    FixByteCodes(bcp32, size, kWordShift, kIdealWordShift);

    current_ += Utils::RoundUp(size, kWordSize);
    WriteOpcode(kSnapshotRaw, size);
    writer_->WriteBytes(bcp32, size);
    delete[] bcp32;
#else
    ASSERT(kWordSize == kIdealWordSize);
    VisitRaw(bcp, size);
#endif
  }

  void VisitRaw(uint8* start, uword size) {
    if (size == 0) return;
    ASSERT(start == current_);
    current_ += Utils::RoundUp(size, kWordSize);
    WriteOpcode(kSnapshotRaw, size);
    writer_->WriteBytes(start, size);
  }

  void WriteInteger(word i);

  void WriteWord(Object* object);

  static int OpcodeLength(word offset) {
    int w = 0;
    int first_byte_bits = 4;
    while (offset < kSnapshotBias ||
           offset >= (1 << first_byte_bits) + kSnapshotBias) {
      w++;
      offset >>= 8;  // Signed shift.
      first_byte_bits--;
      if (first_byte_bits == 0) {
        ASSERT(w == 4);
        ASSERT(offset <= 0 && offset >= kSnapshotBias);
        return 5;
      }
    }
    ASSERT(w <= 4);
    return w + 1;
  }

  void WriteOpcode(int opcode, word offset) {
    int w = OpcodeLength(offset) - 1;
    // bytecode has the opcode in the top 3 bits.
    uint8 opcode_byte = opcode << 5;
    // Move to 64 bit even on 32 bit platforms.
    int64 x = offset;
    int64 bias = -kSnapshotBias;
    // We can do a shift of 32 on bias because it is a 64 bit value.
    x += bias << (8 * w);
    ASSERT(x >= 0 && (x >> 33) == 0);  // Unsigned 33 bit value now.
    // We can encode 4 bits for a 0-byte instruction.  For each byte
    // we add to the instruction we lose one bit in the initial word
    // so we gain only 7 bits per extra byte.  However for the 5-byte
    // encoding where w == 4 we have an extra bit.
    int64 one = 1;  // Value that can legally be shifted by 32.
    if (offset > 0 && w == 4) {
      ASSERT(x == (x & ((one << 33) - 1)));
    } else {
      ASSERT(x == (x & ((one << (4 + 7 * w)) - 1)));
    }
    // The lower part of the bytecode has a unary encoding of the width
    // and the first few bits of the biased offset.
    // w == 0: 0xxxx
    // w == 1: 10xxx
    // w == 2: 110xx
    // w == 3: 1110x
    // w == 4: 1111x
    uint8 width_indicator = 0x1f;
    // Zap the low bits (the xs and the 0s).
    width_indicator &= ~((1 << (5 - w)) - 1);
    // The width indicator and the top part of the x may not overlap.
    uint8 offset_top_part = x >> (8 * w);
    ASSERT((width_indicator & offset_top_part) == 0);

    writer_->WriteByte(opcode_byte | width_indicator | offset_top_part);
    for (int i = w - 1; i >= 0; i--) {
      writer_->WriteByte(x >> (8 * i));
    }
  }

 private:
  SnapshotWriter* writer_;
  PortableAddressMap* address_map_;
  SnapshotOracle* pointer_oracle_;
  SnapshotOracle* smi_oracle_;
  // This is the position in the current object we are serializing.  If we
  // are outputting roots, which are not inside any object, then it is null.
  // Only used for asserts, to ensure we don't skip part of the object
  // without serializint it.
  uint8* current_;
};

// The oracle tells the snapshot encoder at each step, which register to use,
// using knowledge of the future pointers that the encoder will soon encounter.
// Like all good oracles, it does this by cheating: It runs through the
// pointers first, and remembers the order they arrived last time. In the first
// pass it keeps track of all possible decisions for the last kStatesLog2
// pointers. When a new pointer arrives, it discards half the possibilities, by
// making a decision on how to encode the pointer we had, kStatesLog2 calls
// ago.  Then it doubles the number of possibilities by picking either register
// 0 or register 1.  Similarly in the smi mode it does this for Smis, with the
// difference that here one of the registers is locked to zero (ie the choice
// is between register-relative and absolute encoding).
class SnapshotOracle : public PointerVisitor {
 public:
  SnapshotOracle(bool smi_mode, PortableAddressMap* map, SnapshotWriter* writer)
      : smi_mode_(smi_mode), writer_(writer), map_(map) {
    for (int i = 0; i < kStates; i++) {
      costs_[i] = 0;
      regs_[0][i] = 0;
      regs_[1][i] = 0;
    }
  }

  virtual void VisitInteger(uword slot) {
    if (!smi_mode_) return;
    word i = *reinterpret_cast<word*>(slot);
    SimulateInput(i);
  }

  virtual void VisitLiteralInteger(int32 i) {
    if (!smi_mode_) return;
    SimulateInput(i);
  }

  virtual void VisitClass(Object** slot) { VisitBlock(slot, slot + 1); }

  virtual void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) {
      Object* o = *p;
      if (o->IsSmi()) {
        if (!smi_mode_) continue;
        SimulateInput(static_cast<int>(reinterpret_cast<word>(o)));
      } else {
        if (smi_mode_) continue;
        int addr = map_->IdealizedAddress(o);
        int popular_index = writer_->PopularityIndex(HeapObject::cast(o));
        if (popular_index == -1) {
          SimulateInput(addr);
        }
      }
    }
  }

  void WrapUp() {
    int bogus = kStatesLog2 - unused_;
    for (int i = 0; i < bogus; i++) {
      // Add enough bogus entries to the list of pointers to be encoded. These
      // have the effect of forcing the decision to be made on all pointers up
      // to the last real one.
      SimulateInput(0);
    }
  }

  void SimulateInput(int addr) {
    int best_cost = 1000000000;
    int best_reg = -1;
    for (int i = 0; i < kStates; i++) {
      if (costs_[i] >= best_cost) continue;  // Optimization.
      for (int reg = 0; reg < 2; reg++) {
        int diff = addr - regs_[reg][i];
        int cost = ObjectWriter::OpcodeLength(diff >> (smi_mode_ ? 0 : 2));
        if (costs_[i] + cost < best_cost) {
          best_reg = ((i >> (kStatesLog2 - 1)) & 1);
          best_cost = costs_[i] + cost;
        }
      }
    }
    // Oldest choice is in the most significant bit.
    // Find a decision that is now made, using the oldest possibility.
    int decision = best_reg;
    if (unused_ == 0) {
      script_.PushBack(decision);
    } else {
      unused_--;
    }
    for (int i = 0; i < kStatesLog2 - 1; i++) ideals_[i] = ideals_[i + 1];
    ideals_[kStatesLog2 - 1] = addr;
    if (decision == 0) {
      // Keep the left-hand-side entries (the lower half of the leaf arrays),
      // and spread them out.
      for (int i = kStates - 1; i >= 0; i--) {
        int j = i >> 1;
        costs_[i] = costs_[j];
        regs_[0][i] = regs_[0][j];
        regs_[1][i] = regs_[1][j];
      }
    } else {
      // Keep the right-hand-side entries (the upper half of the leaf arrays),
      // and spread them out.
      for (int i = 0; i < kStates; i++) {
        int j = kStates / 2 + (i >> 1);
        costs_[i] = costs_[j];
        regs_[0][i] = regs_[0][j];
        regs_[1][i] = regs_[1][j];
      }
    }
    for (int i = 0; i < kStates; i++) {
      int reg = (i & 1);
      int diff = addr - regs_[reg][i];
      int cost = ObjectWriter::OpcodeLength(diff >> (smi_mode_ ? 0 : 2));
      costs_[i] += cost;
      if (!smi_mode_ || reg == 1) regs_[reg][i] = addr;
    }
  }

  int Consult() { return script_[oracular_pronouncements_++]; }

  void DoneConsulting() { ASSERT(oracular_pronouncements_ == script_.size()); }

 private:
  static const int kStatesLog2 = 6;
  static const int kStates = 1 << kStatesLog2;
  bool smi_mode_;
  SnapshotWriter* writer_;
  // We have a binary tree of k recent possible choices for choosing snapshot
  // byte codes. The arrays represent the 2^k leaves, and the bits of the
  // indices represent the potential choices made.  For each leaf we record the
  // cost (in bytes added to the snapshot) and the values of the two registers.
  int costs_[kStates];
  int regs_[2][kStates];
  int unused_ = kStatesLog2;
  size_t oracular_pronouncements_ = 0;
  int ideals_[kStatesLog2];
  Vector<int> script_;
  PortableAddressMap* map_;
};

class SnapshotDecisionObjectVisitor : public HeapObjectVisitor {
 public:
  explicit SnapshotDecisionObjectVisitor(SnapshotOracle* oracle)
      : oracle_(oracle) {}

  virtual uword Visit(HeapObject* object) {
    object->IterateEverything(oracle_);
    return object->Size();
  }

 private:
  SnapshotOracle* oracle_;
};

void ObjectWriter::WriteInteger(word i) {
  // Large Smis must be purged from the heap before we serialize, since
  // they can't be represented on small devices.
  ASSERT(i <= 0x7fffffff);
  ASSERT(i >= -0x7fffffff - 1);
  int reg = smi_oracle_->Consult();
  if (reg == 0) {
    WriteOpcode(kSnapshotSmi, i);
  } else {
    int32 offset = i - writer_->recent_smi();
    WriteOpcode(kSnapshotRecentSmi, offset);
    writer_->set_recent_smi(i);
  }
}

void ObjectWriter::WriteWord(Object* object) {
  if (object->IsSmi()) {
    WriteInteger(reinterpret_cast<word>(object));
    return;
  }

  HeapObject* heap_object = HeapObject::cast(object);
  uword ideal = address_map_->IdealizedAddress(heap_object) -
                address_map_->doubles_size();
  int popular_index = writer_->PopularityIndex(heap_object);
  if (popular_index != -1) {
    ASSERT(popular_index < kSnapshotNumberOfPopularObjects &&
           popular_index >= 0);
    ASSERT(kSnapshotPopular == 0);
    ASSERT((kSnapshotPopularMask & kSnapshotPopular) == 0);
    ASSERT((kSnapshotPopularMask & (kSnapshotNumberOfPopularObjects - 1)) == 0);
    writer_->WriteByte(popular_index);
  } else {
    int reg = pointer_oracle_->Consult();
    int offset = ideal - writer_->recent(reg);
    WriteOpcode(kSnapshotRecentPointer + reg, offset / kIdealWordSize);
    writer_->set_recent(reg, ideal);
  }
}

void SnapshotWriter::WriteSectionBoundary(ObjectWriter* writer) {
  writer->WriteOpcode(kSnapshotRaw, -1);
}

class SnapshotWriterVisitor : public HeapObjectVisitor {
 public:
  SnapshotWriterVisitor(PortableAddressMap* map, SnapshotWriter* writer,
                        SnapshotOracle* pointer_oracle,
                        SnapshotOracle* smi_oracle)
      : address_map_(map),
        writer_(writer),
        pointer_oracle_(pointer_oracle),
        smi_oracle_(smi_oracle) {}

  virtual uword Visit(HeapObject* object) {
    ASSERT(!object->IsStack());
    int size = object->Size();
    if (object->IsDouble()) {
      ASSERT(doubles_mode_);
      writer_->WriteDouble(Double::cast(object)->value());
      // We have to consume one oracular pronouncement (for the class
      // field of the double) to keep the oracle in sync with the
      // writer.
      pointer_oracle_->Consult();
      return size;
    }
    doubles_mode_ = false;
    ObjectWriter object_writer(writer_, address_map_, pointer_oracle_,
                               smi_oracle_, object);
    object->IterateEverything(&object_writer);
    object_writer.End(object->address() + size);
    return size;
  }

 private:
  bool doubles_mode_ = true;
  PortableAddressMap* address_map_;
  SnapshotWriter* writer_;
  SnapshotOracle* pointer_oracle_;
  SnapshotOracle* smi_oracle_;
};

void PopularityCounter::VisitClass(Object** slot) {
  VisitBlock(slot, slot + 1);
}

void PopularityCounter::VisitBlock(Object** start, Object** end) {
  for (Object** p = start; p < end; p++) {
    if (!(*p)->IsSmi()) {
      HeapObject* h = HeapObject::cast(*p);
      // Doubles (moved already or not) are not eligible for the popular objects
      // table.
      if (h->HasForwardingAddress()) continue;
      if (h->IsDouble()) continue;
      // Causes confusion if the double class is one of the popular objects, and
      // there's no point anyway since it is coded specially and will not use
      // its slot in the popular objects table.
      if (h->IsClass() &&
          Class::cast(h)->instance_format().type() ==
              InstanceFormat::DOUBLE_TYPE) {
        continue;
      }
      auto it = popularity_.Find(h);
      if (it == popularity_.End()) {
        popularity_[h] = 1;
      } else {
        it->second++;
      }
    }
  }
}

void PopularityCounter::FindMostPopular() {
  for (auto p : popularity_) most_popular_.PushBack(p);
  most_popular_.Sort(PopularityCompare);
}

void PopularityCounter::VisitMostPopular(PointerVisitor* visitor) {
  unsigned i = 0;
  while (i < kSnapshotNumberOfPopularObjects && i < most_popular_.size()) {
    visitor->Visit(reinterpret_cast<Object**>(&most_popular_[i].first));
    i++;
  }
  Object* filler = Smi::FromWord(0);
  while (i < kSnapshotNumberOfPopularObjects) {
    visitor->Visit(&filler);
    i++;
  }
}

int PopularityCounter::PopularityIndex(HeapObject* object) {
  for (unsigned i = 0; i < 32 && i < most_popular_.size(); i++) {
    if (object == most_popular_[i].first) {
      return i;
    }
  }
  return -1;
}

List<uint8> SnapshotWriter::WriteProgram(Program* program) {
  ASSERT(program->is_optimized());

  program->SnapshotGC(&popularity_counter_);
  PortableAddressMap portable_addresses(function_offsets_, class_offsets_);
  program->heap()->IterateObjects(&portable_addresses);

  // Emit recognizable header.
  WriteByte(0xbe);
  WriteByte(0xef);

  // Emit version of the VM.
  const char* version = GetVersion();
  int version_length = strlen(version);
  WriteSize(version_length);
  WriteBytes(reinterpret_cast<const uint8*>(version), version_length);

  // Emit size of the heap for various scenarios.
  WriteSize(portable_addresses.total_floats());
  WriteSize(portable_addresses.total_size().ComputeSizeInBytes(
      kBigPointerSmallFloat));
  WriteSize(
      portable_addresses.total_size().ComputeSizeInBytes(kBigPointerBigFloat));
  WriteSize(portable_addresses.total_size().ComputeSizeInBytes(
      kSmallPointerSmallFloat));
  WriteSize(portable_addresses.total_size().ComputeSizeInBytes(
      kSmallPointerBigFloat));

  SnapshotOracle pointer_oracle(false, &portable_addresses, this);
  emitting_popular_list_ = true;
  popularity_counter_.VisitMostPopular(&pointer_oracle);
  emitting_popular_list_ = false;
  program->IterateRootsIgnoringSession(&pointer_oracle);
  SnapshotDecisionObjectVisitor sdov(&pointer_oracle);
  program->heap()->IterateObjects(&sdov);
  pointer_oracle.WrapUp();

  SnapshotOracle smi_oracle(true, NULL, this);
  popularity_counter_.VisitMostPopular(&smi_oracle);
  program->IterateRootsIgnoringSession(&smi_oracle);
  SnapshotDecisionObjectVisitor sdov2(&smi_oracle);
  program->heap()->IterateObjects(&sdov2);
  smi_oracle.WrapUp();

  ObjectWriter object_writer(this, &portable_addresses, &pointer_oracle,
                             &smi_oracle);

  WriteSectionBoundary(&object_writer);
  emitting_popular_list_ = true;
  popularity_counter_.VisitMostPopular(&object_writer);
  emitting_popular_list_ = false;

  WriteSectionBoundary(&object_writer);
  program->IterateRootsIgnoringSession(&object_writer);

  WriteSectionBoundary(&object_writer);
  SnapshotWriterVisitor writer_visitor(&portable_addresses, this,
                                       &pointer_oracle, &smi_oracle);
  program->heap()->IterateObjects(&writer_visitor);

  WriteSectionBoundary(&object_writer);

  smi_oracle.DoneConsulting();
  pointer_oracle.DoneConsulting();

  List<uint8> result = snapshot_.Sublist(0, position_);

  program->set_snapshot_hash(ComputeSnapshotHash(result));

  return result;
}

void SnapshotWriter::GrowCapacity(int extra) {
  int growth = Utils::Maximum(1 * MB, extra);
  int capacity = snapshot_.length() + growth;
  uint8* data = static_cast<uint8*>(realloc(snapshot_.data(), capacity));
  snapshot_ = List<uint8>(data, capacity);
}

}  // namespace dartino
