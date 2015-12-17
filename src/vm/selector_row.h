// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SELECTOR_ROW_H_
#define SRC_VM_SELECTOR_ROW_H_

#ifdef FLETCH_ENABLE_LIVE_CODING

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/utils.h"

#include "src/vm/hash_set.h"
#include "src/vm/object.h"
#include "src/vm/vector.h"

namespace fletch {

typedef Vector<Class*> ClassVector;
typedef Vector<Function*> FunctionVector;

class Range {
 public:
  typedef Vector<Range> List;

  Range(int begin, int end) : begin_(begin), end_(end) { ASSERT(end > begin); }

  int begin() const { return begin_; }
  void set_begin(int value) { begin_ = value; }

  int end() const { return end_; }
  void set_end(int value) { end_ = value; }

  int size() const { return end_ - begin_; }

  Range WithOffset(int offset) const {
    return Range(begin_ + offset, end_ + offset);
  }

  bool IsSame(const Range other) const {
    return end() == other.end() && begin() == other.begin();
  }

  bool IsBefore(const Range other) const { return end() < other.begin(); }

  bool IsAfter(const Range other) const { return begin() > other.end(); }

  bool Overlap(const Range other) const {
    return !IsBefore(other) && !IsAfter(other);
  }

  bool ContainsBeginOf(const Range other) const {
    return begin() <= other.begin() && other.begin() <= end();
  }

  bool ContainsEndOf(const Range other) const {
    return begin() <= other.end() && other.end() <= end();
  }

  bool Contains(const Range other) const {
    return ContainsBeginOf(other) && ContainsEndOf(other);
  }

 private:
  int begin_;
  int end_;
};

class SelectorRow {
 public:
  explicit SelectorRow(int selector)
      : selector_(selector), offset_(-1), variants_(0), begin_(-1), end_(-1) {}

  int begin() const { return begin_; }

  int end() const { return end_; }

  bool IsMatched() const { return variants_ > 0; }

  int offset() const { return offset_; }

  void set_offset(int value) { offset_ = value; }

  void Finalize();

  int ComputeTableSize() {
    ASSERT(IsMatched());
    return end_ - begin_;
  }

  void FillTable(Program* program, Array* table);

  // The bottom up construction order guarantees that more specific methods
  // always get defined before less specific ones.
  void DefineMethod(Class* clazz, Function* method) {
#ifdef DEBUG
    for (int i = 0; i < variants_; i++) {
      // No class should have multiple method definitions for a
      // single given selector.
      ASSERT(classes_[i] != clazz);
    }
#endif
    classes_.PushBack(clazz);
    methods_.PushBack(method);
    variants_++;
  }

  static bool RangeSizeCompare(const Range& a, const Range& b) {
    return a.size() > b.size();
  }

  static bool RangeBeginCompare(const Range& a, const Range& b) {
    return a.begin() < b.begin();
  }

  static bool Compare(SelectorRow* const* a, SelectorRow* const* b) {
    int a_size = (*a)->ComputeTableSize();
    int b_size = (*b)->ComputeTableSize();

    // Sort by decreasing sizes (first) and decreasing begin index.
    // According to the litterature, this leads to fewer holes and
    // faster row offset computation.
    return (a_size == b_size) ? (*a)->begin() > (*b)->begin() : a_size > b_size;
  }

  const Range::List& ranges() const { return ranges_; }

 private:
  void AddToRanges(Range range);

  const int selector_;
  int offset_;

  // We keep track of all the different implementations of
  // the selector corresponding to this row.
  int variants_;
  ClassVector classes_;
  FunctionVector methods_;
  Range::List ranges_;

  // All used entries in this row are in the [begin, end) interval.
  int begin_;
  int end_;
};

class RowFitter {
 public:
  RowFitter() : single_range_start_index_(0), limit_(0) {
    // TODO(ajohnsen): Let the last range be implicit?
    free_slots_.PushBack(Range(0, INT_MAX));
  }

  int limit() const { return limit_; }

  int Fit(SelectorRow* row);

  int FitRowWithSingleRange(SelectorRow* row);

 private:
  void MarkOffsetAsUsed(int offset);

  int FindOffset(const Range::List& ranges, int min_row_index,
                 size_t* result_slot_index);

  int MatchRemaining(int offset, const Range::List& ranges, size_t slot_index);

  size_t MoveBackToCover(const Range range, size_t slot_index);

  size_t MoveForwardToCover(const Range range, size_t slot_index);

  void UpdateFreeSlots(int offset, const Range::List& ranges,
                       size_t slot_index);

  size_t FitInFreeSlot(const Range range, size_t slot_index);

  HashSet<intptr_t> used_offsets_;
  Range::List free_slots_;
  int single_range_start_index_;
  int limit_;
};

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING

#endif  // SRC_VM_SELECTOR_ROW_H_
