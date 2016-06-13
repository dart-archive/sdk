// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SNAPSHOT_H_
#define SRC_VM_SNAPSHOT_H_

#include "src/shared/globals.h"
#include "src/shared/list.h"
#include "src/shared/platform.h"

#include "src/vm/hash_map.h"
#include "src/vm/object.h"
#include "src/vm/process.h"
#include "src/vm/program.h"
#include "src/vm/vector.h"

namespace dartino {

class ObjectWriter;

// Used for representing the size or address of a [HeapObject] in a portable
// way.
//
// It counts the number of pointer-sized values, double/float values and fixed
// (byte) values.
//
// Converting a [PortableSize] to the actual size can be done via the
// [ComputeSizeInBytes] by passing in the size of pointers/doubles.
const int kFloatSizeMask = 1 << 0;
const int kPointerSizeMask = 1 << 1;
const int kSmallFloat = 0;
const int kLargeFloat = kFloatSizeMask;
const int kSmallPointer = 0;
const int kLargePointer = kPointerSizeMask;
enum MemoryLayout {
  kSmallPointerSmallFloat = kSmallFloat + kSmallPointer,
  kSmallPointerBigFloat = kLargeFloat + kSmallPointer,
  kBigPointerSmallFloat = kSmallFloat + kLargePointer,
  kBigPointerBigFloat = kLargeFloat + kLargePointer,
};

class PortableSize {
 public:
  PortableSize() {}

  uword IdealizedSize() const {
    return ComputeSizeInBytes(kSmallPointerSmallFloat);
  }

  uword ComputeSizeInBytes(MemoryLayout layout) const {
    uword pointer_shift =
        ((layout & kPointerSizeMask) == kSmallPointer) ? 2 : 3;
    uword float_shift = ((layout & kFloatSizeMask) == kSmallFloat) ? 2 : 3;

    uword byte_size =
        (num_pointers_ << pointer_shift) + (num_floats_ << float_shift);

    if (pointer_shift == 2) {
      return byte_size + fixed_size_32_;
    } else {
      return byte_size + fixed_size_64_;
    }
  }

  static PortableSize Pointer(int count = 1) {
    return PortableSize(count, 0, 0, 0);
  }

  static PortableSize Fixed(int bytes) {
    return PortableSize(0, Utils::RoundUp(bytes, 4), Utils::RoundUp(bytes, 8),
                        0);
  }

  static PortableSize Float(int floats = 1) {
    return PortableSize(0, 0, 0, floats);
  }

  PortableSize& operator+=(const PortableSize& size) {
    num_pointers_ += size.num_pointers_;
    fixed_size_32_ += size.fixed_size_32_;
    fixed_size_64_ += size.fixed_size_64_;
    num_floats_ += size.num_floats_;
    return *this;
  }

 private:
  PortableSize(uword pointers, uword fixed_size_32, uword fixed_size_64,
               uword floats)
      : num_pointers_(pointers),
        fixed_size_32_(fixed_size_32),
        fixed_size_64_(fixed_size_64),
        num_floats_(floats) {}

  uword num_pointers_ = 0;
  uword fixed_size_32_ = 0;
  uword fixed_size_64_ = 0;
  uword num_floats_ = 0;
};

typedef HashMap<Function*, PortableSize> FunctionOffsetsType;
typedef HashMap<Class*, PortableSize> ClassOffsetsType;

// The byte codes used to encode the snapshot. Not to be confused with
// the byte codes that encode the actual Dart program. Each byte code
// is followed by 0, 1, 2 or 4 bytes of argument.
enum kSnapshotOpcodes {
  // 00xxxxxx are the popular objects.  These are single-byte instructions.
  kSnapshotPopular = 0,
  kSnapshotPopularMask = 0xc0,
  kSnapshotNumberOfPopularObjects = 0x40,

  // ooo ww xxx are the other opcodes.  Opcodes 0 and 1 are taken by the
  // popular objects.  ww gives the number of extra bytes that help make up the
  // value, 0, 1, 2 or 4.  xxx are is the biased starting point from -1 to 6,
  // and each extra byte specified by w is combined with the previous values by
  // x = (x << 8) | next_byte;
  // There are several places where ReadWord() relies on the order and bit
  // patterns of these opcodes.
  kSnapshotRecentPointer = 2,
  kSnapshotRecentPointer0 = 2,
  kSnapshotRecentPointer1 = 3,
  kSnapshotRecentSmi = 4,  // Relative to previous Smi.
  kSnapshotSmi = 5,
  kSnapshotExternal = 6,  // Pointer into C++ heap.
  kSnapshotRaw = 7,       // Raw number of bytes follow.

  // Section boundaries are marked as 111 00 000, which corresponds to a
  // a run of raw bytes, length -1, which is otherwise illegal.
};

static const int kSnapshotBias = -1;

// All addresses in the snapshot are based on these idealized word and floating
// point sizes.
static const word kIdealWordSize = 4;
static const word kIdealFloatSize = 4;
// One class pointer plus one float is a boxed float.
static const word kIdealBoxedFloatSize = kIdealWordSize + kIdealFloatSize;

inline int OpCode(uint8 byte_code) { return byte_code >> 5; }

inline bool IsOneBytePopularByteCode(uint8 byte_code) {
  return (byte_code & kSnapshotPopularMask) == kSnapshotPopular;
}

inline int ArgumentBytes(uint8 byte_code) {
  ASSERT(!IsOneBytePopularByteCode(byte_code));
  int w = (byte_code >> 3) & 3;
  // This is a branchless way to say if (w == 3) w = 4;
  w += w & (w >> 1);
  return w;
}

inline bool IsSectionBoundary(uint8 b) {
  if (OpCode(b) != kSnapshotRaw) return false;
  return (b & 31) == 0;
}

class SnapshotReader {
 public:
  explicit SnapshotReader(List<uint8> snapshot)
      : snapshot_(snapshot), position_(0) {
    for (int i = 0; i < 3; i++) recents_[i] = 0;
  }
  ~SnapshotReader() {}

  // Reads an entire program.
  Program* ReadProgram();

 protected:
  // Read the next object from the snapshot.
  word ReadWord();

  uint8 ReadByte() { return snapshot_[position_++]; }
  void ReadBytes(int length, uint8* values);
  unsigned ReadSize();
  double ReadDouble();

  friend class ByteArray;
  friend class Class;
  friend class Function;
  friend class Instance;
  friend class Initializer;
  friend class DispatchTableEntry;
  friend class ReaderVisitor;

 private:
  List<uint8> snapshot_;
  int position_;
  word recents_[3];
  uword base_ = 0;

  int index_ = 0;
  int raw_to_do_ = 0;

#ifdef DARTINO64
  HashMap<uword, uword> location_map_;
#endif

  Object* popular_objects_[kSnapshotNumberOfPopularObjects];
  static word intrinsics_table_[];

  int ReadHeapSizeFrom(int position);
  void BuildLocationMap(Program* program, word total_floats, uword heap_size);
  int Skip(int position, int words_to_skip);
  void ReadSectionBoundary();
};

class PopularityCounter : public PointerVisitor {
 public:
  virtual void VisitClass(Object** slot);
  virtual void VisitBlock(Object** start, Object** end);

  void FindMostPopular();
  void VisitMostPopular(PointerVisitor* visitor);

  // Returns an index from 0 to 31 if the object is one of the 32 most popular
  // objects on the heap, otherwise -1.
  int PopularityIndex(HeapObject* object);

 private:
  typedef Pair<HeapObject*, int> PopPair;
  static bool PopularityCompare(const PopPair* a, const PopPair* b) {
    int a_count = a->second;
    int b_count = b->second;
    int a_size = a->first->Size();
    int b_size = b->first->Size();
    // Place small popular objects near the start.
    return (a_count * kWordSize * 2) / a_size >
           (b_count * kWordSize * 2) / b_size;
  }

  HashMap<HeapObject*, int> popularity_;
  Vector<PopPair> most_popular_;
};

class SnapshotWriter {
 public:
  SnapshotWriter(FunctionOffsetsType* function_offsets,
                 ClassOffsetsType* class_offsets)
      : snapshot_(List<uint8>::New(1 * MB)),
        position_(0),
        index_(1),
        function_offsets_(function_offsets),
        class_offsets_(class_offsets) {
    for (int i = 0; i < 2; i++) {
      recent_[i] = 0;
      lru_[i] = 0;
    }
  }

  ~SnapshotWriter() {}

  // Create a snapshot of a program. The program must be folded.
  List<uint8> WriteProgram(Program* program);

  void WriteByte(uint8 value);
  void WriteBytes(const uint8* values, int length);
  void WriteDouble(double value);
  void WriteSize(unsigned size);
  void WriteSectionBoundary(ObjectWriter* writer);

  void Forward(HeapObject* object);
  Class* ClassFor(HeapObject* object);

  friend class SnapshotWriterVisitor;
  friend class Initializer;
  friend class DispatchTableEntry;

  word recent_smi() { return recent_smi_; }
  void set_recent_smi(word smi) { recent_smi_ = smi; }
  word recent(int i) {
    ASSERT(i >= 0 && i < 2);
    return recent_[i];
  }
  void set_recent(int i, word addr) {
    ASSERT(i >= 0 && i < 2);
    if (i != 0) recent_[i] = addr;
    recent_[i] = addr;
    lru_[i] = counter_++;
  }
  word lru(int i) {
    ASSERT(i >= 0 && i < 2);
    return lru_[i];
  }

  int PopularityIndex(HeapObject* object) {
    if (emitting_popular_list_) return -1;
    return popularity_counter_.PopularityIndex(object);
  }

 private:
  List<uint8> snapshot_;
  int position_;
  int index_;
  word recent_smi_ = 0;
  // Two registers record recently referenced objects.  New non-popular object
  // references are coded as offsets from these recent objects.
  word recent_[2];
  // Track how recently used the register was, to implement the
  // least-recently-used register choice.
  word lru_[2];
  int counter_ = 0;

  // The snapshot contains the heap size needed in order to read in the snapshot
  // without reallocation both for a 32-bit system and for a 64-bit system.
  PortableSize heap_size_;

  FunctionOffsetsType* function_offsets_;
  ClassOffsetsType* class_offsets_;

  PopularityCounter popularity_counter_;
  bool emitting_popular_list_ = false;

  void EnsureCapacity(int extra) {
    if (position_ + extra >= snapshot_.length()) GrowCapacity(extra);
  }

  void GrowCapacity(int extra);
};

uint32_t ComputeSnapshotHash(List<uint8> snapshot);

}  // namespace dartino

#endif  // SRC_VM_SNAPSHOT_H_
