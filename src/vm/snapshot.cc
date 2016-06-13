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
        word x = (b & 7) + kSnapshotBias;
        ASSERT(x >= 0);
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
    word x = (b & 7) + kSnapshotBias;
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
               HeapObject* current = NULL)
      : writer_(writer),
        address_map_(map),
        current_(current == NULL ? 0 : reinterpret_cast<uint8*>(
                                           current->address())) {}

  virtual void VisitClass(Object** p) {
    ASSERT(current_ == reinterpret_cast<uint8*>(p));
    WriteWord(*p, reinterpret_cast<uword>(p));
    current_ += kWordSize;
  }

  void VisitBlock(Object** start, Object** end) {
    if (start == end) return;
    uint8* block_start = reinterpret_cast<uint8*>(start);
    ASSERT(current_ == 0 || block_start == current_);
    for (Object** p = start; p < end; p++) {
      WriteWord(*p, reinterpret_cast<uword>(p));
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

  int32 abs(int32 x) {
    if (x < 0) return -x;
    return x;
  }

  void WriteInteger(word i) {
    // Large Smis must be purged from the heap before we serialize, since
    // they can't be represented on small devices.
    ASSERT(i <= 0x7fffffff);
    ASSERT(i >= -0x7fffffff - 1);
    int32 offset = i - writer_->recent_smi();
    if (offset < -2 || abs(i) < abs(offset)) {
      WriteOpcode(kSnapshotSmi, i);
    } else {
      WriteOpcode(kSnapshotRecentSmi, offset);
      writer_->set_recent_smi(i);
    }
  }

  void WriteWord(Object* object, uword from = 0) {
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
      ASSERT((kSnapshotPopularMask & (kSnapshotNumberOfPopularObjects - 1)) ==
             0);
      writer_->WriteByte(popular_index);
    } else {
      // If there's a register that we can use that gives a 1-byte encoding,
      // then just use that.
      for (int i = 0; i < 2; i++) {
        word offset = ideal - writer_->recent(i);
        if (OpcodeLength(offset / kIdealWordSize) == 1) {
          WriteOpcode(kSnapshotRecentPointer + i, offset / kIdealWordSize);
          writer_->set_recent(i, ideal);
          return;
        }
      }
      int reg = -1;
      word offset0 = ideal - writer_->recent(0);
      word offset1 = ideal - writer_->recent(1);
      // For each encoding length, check if there is a register that we can
      // pick that will give that length.  If there are two, pick the least
      // recently used.
      for (int goal = 2; goal <= 5; goal++) {
        word offset0 = ideal - writer_->recent(0);
        word offset1 = ideal - writer_->recent(1);
        if (OpcodeLength(offset0 / kIdealWordSize) == goal) {
          if (OpcodeLength(offset1 / kIdealWordSize) == goal) {
            if (writer_->lru(0) < writer_->lru(1)) {
              reg = 0;
            } else {
              reg = 1;
            }
          } else {
            reg = 0;
          }
          break;
        } else if (OpcodeLength(offset1 / kIdealWordSize) == goal) {
          reg = 1;
          break;
        }
      }
      word offset = reg ? offset1 : offset0;
      ASSERT(reg != -1);
      WriteOpcode(kSnapshotRecentPointer + reg, offset / kIdealWordSize);
      writer_->set_recent(reg, ideal);
    }
  }

  int OpcodeLength(word offset) {
    int w = 0;
    // We can't code for a w with 3, so we keep going to 4 if we hit that one.
    while (offset < kSnapshotBias || offset > 7 + kSnapshotBias || w == 3) {
      w++;
      offset >>= 8;  // Signed shift.
    }
    ASSERT(w >= 0 && w <= 4 && w != 3);
    return w + 1;
  }

  void WriteOpcode(int opcode, word offset) {
    int w = 0;
    uint8 bytes[4] = {0, 0, 0, 0};
    // We can't code for a w with 3, so we keep going to 4 if we hit that one.
    while (offset < kSnapshotBias || offset > 7 + kSnapshotBias || w == 3) {
      w++;
      bytes[3] = bytes[2];
      bytes[2] = bytes[1];
      bytes[1] = bytes[0];
      bytes[0] = offset;
      offset >>= 8;  // Signed shift.
    }
    ASSERT(w >= 0 && w <= 4 && w != 3);
    uint8 opcode_byte = (opcode << 5) | ((w == 4 ? 3 : w) << 3) |
                        ((offset - kSnapshotBias) & 7);
    writer_->WriteByte(opcode_byte);
    writer_->WriteBytes(bytes, w);
  }

 private:
  SnapshotWriter* writer_;
  PortableAddressMap* address_map_;
  // This is the position in the current object we are serializing.  If we
  // are outputting roots, which are not inside any object, then it is null.
  // Only used for asserts, to ensure we don't skip part of the object
  // without serializint it.
  uint8* current_;
};

void SnapshotWriter::WriteSectionBoundary(ObjectWriter* writer) {
  writer->WriteOpcode(kSnapshotRaw, -1);
}

class SnapshotWriterVisitor : public HeapObjectVisitor {
 public:
  SnapshotWriterVisitor(PortableAddressMap* map, SnapshotWriter* writer)
      : address_map_(map), writer_(writer) {}

  virtual uword Visit(HeapObject* object) {
    ASSERT(!object->IsStack());
    int size = object->Size();
    if (object->IsDouble()) {
      ASSERT(doubles_mode_);
      writer_->WriteDouble(Double::cast(object)->value());
      return size;
    }
    doubles_mode_ = false;
    ObjectWriter object_writer(writer_, address_map_, object);
    object->IterateEverything(&object_writer);
    object_writer.End(object->address() + size);
    return size;
  }

 private:
  bool doubles_mode_ = true;
  PortableAddressMap* address_map_;
  SnapshotWriter* writer_;
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

  ObjectWriter object_writer(this, &portable_addresses);

  WriteSectionBoundary(&object_writer);
  emitting_popular_list_ = true;
  popularity_counter_.VisitMostPopular(&object_writer);
  emitting_popular_list_ = false;

  WriteSectionBoundary(&object_writer);
  program->IterateRootsIgnoringSession(&object_writer);

  WriteSectionBoundary(&object_writer);
  SnapshotWriterVisitor writer_visitor(&portable_addresses, this);
  program->heap()->IterateObjects(&writer_visitor);

  WriteSectionBoundary(&object_writer);

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
