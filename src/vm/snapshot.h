// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SNAPSHOT_H_
#define SRC_VM_SNAPSHOT_H_

#include "src/shared/globals.h"
#include "src/shared/list.h"
#include "src/shared/platform.h"

#include "src/vm/object.h"
#include "src/vm/process.h"
#include "src/vm/program.h"

namespace fletch {

class SnapshotReader {
 public:
  explicit SnapshotReader(List<uint8> snapshot)
      : snapshot_(snapshot),
        position_(0),
        large_integer_class_(NULL),
        memory_(NULL),
        top_(0),
        index_(0) {
  }
  virtual ~SnapshotReader() { }

  // Reads an entire program.
  Program* ReadProgram();

 protected:
  // Read the next object from the snapshot.
  Object* ReadObject();

  // Helpers for reading primitives. Only accessible from the
  // objects that need to read themselves from a snapshot.
  uint8 ReadByte() { return snapshot_[position_++]; }
  void ReadBytes(int length, uint8* values);
  int64 ReadInt64();
  double ReadDouble();

  // Support for storing references and referring to them (back references).
  void AddReference(HeapObject* object);
  HeapObject* Dereference(int index);

  friend class ByteArray;
  friend class Class;
  friend class Function;
  friend class Instance;
  friend class ExternalMemory;
  friend class Array;
  friend class TwoByteString;
  friend class LargeInteger;
  friend class Double;
  friend class Initializer;
  friend class ReaderVisitor;

 private:
  List<uint8> snapshot_;
  int position_;

  Class* large_integer_class_;

  // Memory area used for allocating objects as they are read in.
  Chunk* memory_;
  uword top_;

  List<HeapObject*> backward_references_;
  int index_;

  HeapObject* Allocate(int size) {
    uword top = top_;
    HeapObject* result = HeapObject::FromAddress(top);
    top_ = top + size;
    return result;
  }

  int ReadHeapSizeFrom(int position);
};

class SnapshotWriter {
 public:
  SnapshotWriter()
      : snapshot_(List<uint8>::New(1 * MB)),
        position_(0),
        index_(1),
        alternative_heap_size_(0) { }
  virtual ~SnapshotWriter() { }

  // Create a snapshot of a program. The program must be folded.
  List<uint8> WriteProgram(Program* program);

 protected:
  void WriteByte(uint8 value);
  void WriteBytes(int length, uint8* values);
  void WriteInt64(int64 value);
  void WriteDouble(double value);
  void WriteHeader(InstanceFormat::Type type, int elements = 0);

  void WriteObject(Object* object);

  void Forward(HeapObject* object);
  Class* ClassFor(HeapObject* object);

  friend class ByteArray;
  friend class Class;
  friend class Function;
  friend class Instance;
  friend class ExternalMemory;
  friend class Array;
  friend class HashTable;
  friend class TwoByteString;
  friend class LargeInteger;
  friend class Double;
  friend class Initializer;
  friend class UnmarkSnapshotVisitor;
  friend class WriterVisitor;

 private:
  List<uint8> snapshot_;
  int position_;
  int index_;

  // The snapshot contains the heap size needed in order to read in the snapshot
  // without reallocation both for a 32-bit system and for a 64-bit system.
  // When writing the snapshot from a 32-bit system, the alternative heap size
  // is the size needed for the snapshot on a 64-bit system. When writing the
  // snapshot from a 64-bit system, the alternative heap size is the size needed
  // for the snapshot on a 32-bit system.
  int alternative_heap_size_;

  void WriteHeapSizeTo(int position, int size);

  void EnsureCapacity(int extra) {
    if (position_ + extra >= snapshot_.length()) GrowCapacity(extra);
  }

  void GrowCapacity(int extra);
};

}  // namespace fletch


#endif  // SRC_VM_SNAPSHOT_H_
