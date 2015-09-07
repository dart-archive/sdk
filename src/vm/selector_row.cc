// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_LIVE_CODING

#include "src/vm/selector_row.h"

#include "src/shared/bytecodes.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

#include "src/vm/program.h"

namespace fletch {

SelectorRow::Kind SelectorRow::Finalize() {
  int variants = variants_;
  ASSERT(variants > 0);
  if (variants <= kFewVariantsThreshold) return LINEAR;

  ASSERT(begin_ == -1 && end_ == -1);
  Class* first = classes_[0];
  begin_ = first->id();
  end_ = first->child_id();

  for (int i = 1; i < variants; i++) {
    Class* clazz = classes_[i];
    int begin = clazz->id();
    int end = clazz->child_id();
    if (begin < begin_) begin_ = begin;
    if (end > end_) end_ = end;
  }

  // Collect the minimum number of ranges, spanning all the class ranges.
  // The ranges defined by the classes are in a special pattern: one either
  // fully contain another, or has no overlap. However, ranges may come
  // immediately aftereach other. The following creates a set of ranges that:
  //  - Contains all class ranges.
  //  - Two immedialy connected ranges are merged into one.
  for (int i = 0; i < variants; i++) {
    Class* clazz = classes_[i];
    Range range = Range(clazz->id(), clazz->child_id());
    AddToRanges(range);
  }

  // TODO(ajohnsen): Waste to double sort. Consider single iteration to find
  // largest, swap with begin, and then begin-sort.
  ranges_.Sort(RangeSizeCompare);
  ranges_.Sort(RangeBeginCompare, 1, ranges_.size() - 1);

  return TABLE;
}

void SelectorRow::AddToRanges(Range range) {
  size_t i = 0;
  while (i != ranges_.size()) {
    if (!ranges_[i].Overlap(range)) {
      i++;
    } else if (ranges_[i].Contains(range)) {
      // Already covered.
      return;
    } else {
      // Expand range, remove current and continue with updated range. This
      // handles the case where two ranges may come immediately after each
      // other.
      if (ranges_[i].begin() < range.begin()) {
        range.set_begin(ranges_[i].begin());
      }
      if (range.end() < ranges_[i].end()) {
        range.set_end(ranges_[i].end());
      }
      ranges_.Remove(i);
    }
  }
  ranges_.PushBack(range);
}

void SelectorRow::FillTable(Program* program, Array* table) {
  ASSERT(kind() == TABLE);
  int offset = offset_;
  for (int i = 0, length = variants_; i < length; i++) {
    Class* clazz = classes_[i];
    Function* method = methods_[i];
    Array* entry = Array::cast(program->CreateArray(4));
    entry->set(0, Smi::FromWord(offset));
    entry->set(1, Smi::FromWord(selector_));
    entry->set(2, method);
    entry->set(3, NULL);

    int id = clazz->id();
    int limit = clazz->child_id();
    while (id < limit) {
      if (table->get(offset + id)->IsNull()) {
        table->set(offset + id, entry);
        id++;
      } else {
        // Because the variants are ordered so we deal with the most specific
        // implementations first, we can skip the entire subclass hierarchy
        // when we find that the method we're currently filling into the table
        // is overridden by an already processed implementation.
        id = program->class_at(id)->child_id();
      }
    }
  }
}

int SelectorRow::FillLinear(Program* program, Array* table) {
  ASSERT(kind() == LINEAR);
  int index = offset_;

  table->set(index++, Smi::FromWord(Selector::ArityField::decode(selector_)));
  table->set(index++, Smi::FromWord(selector_));
  table->set(index++, NULL);
  table->set(index++, NULL);

  for (int i = 0; i < variants_; i++) {
    Class* clazz = classes_[i];
    Function* method = methods_[i];
    table->set(index++, Smi::FromWord(clazz->id()));
    table->set(index++, Smi::FromWord(clazz->child_id()));
    table->set(index++, NULL);
    table->set(index++, method);
  }

  static const Names::Id name = Names::kNoSuchMethodTrampoline;
  Function* target = program->object_class()->LookupMethod(
      Selector::Encode(name, Selector::METHOD, 0));

  table->set(index++, Smi::FromWord(0));
  table->set(index++, Smi::FromWord(Smi::kMaxPortableValue));
  table->set(index++, NULL);
  table->set(index++, target);

  ASSERT(index - offset_ == ComputeLinearSize());
  return index;
}

int RowFitter::Fit(SelectorRow* row) {
  ASSERT(row->kind() == SelectorRow::TABLE);

  const Range::List& ranges = row->ranges();

  size_t slot_index;
  int offset = FindOffset(ranges, row->begin(), &slot_index);

  UpdateFreeSlots(offset, ranges, slot_index);

  MarkOffsetAsUsed(offset);
  return offset;
}

int RowFitter::FitRowWithSingleRange(SelectorRow* row) {
  ASSERT(row->kind() == SelectorRow::TABLE);
  ASSERT(row->ranges().size() == 1);

  Range range = row->ranges().Front();

  size_t index = single_range_start_index_;

  while (index < free_slots_.size() - 1) {
    Range& slot = free_slots_[index];
    int offset = slot.begin() - range.begin();
    if (offset >= 0 &&
        range.size() <= slot.size() &&
        used_offsets_.Count(offset) == 0) {
      // Simply move the start offset of the slot. If the slot is now full,
      // the next row will detect it and move index accordingly.
      slot.set_begin(slot.begin() + range.size());
      single_range_start_index_ = index;

      MarkOffsetAsUsed(offset);
      return offset;
    }
    index++;
  }

  single_range_start_index_ = index;

  Range& slot = free_slots_[index];
  int offset = Utils::Maximum(0, slot.begin() - range.begin());
  while (used_offsets_.Count(offset) > 0) {
    offset++;
  }
  slot.set_begin(offset + range.end());

  MarkOffsetAsUsed(offset);
  return offset;
}

void RowFitter::MarkOffsetAsUsed(int offset) {
  ASSERT(used_offsets_.Count(offset) == 0);
  used_offsets_.Insert(offset);
  // Keep track of the highest used offset.
  if (offset > limit_) limit_ = offset;
}

int RowFitter::FindOffset(const Range::List& ranges,
                          int min_row_index,
                          size_t* result_slot_index) {
  ASSERT(single_range_start_index_ == 0);
  const Range largest_range = ranges.Front();

  size_t index = 0;
  size_t length = free_slots_.size() - 1;
  int min_start = 0;

  while (index < length) {
    const Range slot = free_slots_[index];

    int start = Utils::Maximum(
        min_start,
        Utils::Maximum(slot.begin(), largest_range.begin()));
    int end = slot.end() - largest_range.size();

    while (start < end) {
      int offset = start - largest_range.begin();
      ASSERT(offset >= 0);

      // At this point we expect the first (largest) range to match the 'it'
      // slot.
      ASSERT(slot.Contains(largest_range.WithOffset(offset)));

      // Pad to guarantee unique offsets.
      if (used_offsets_.Count(offset) > 0) {
        start++;
        continue;
      }

      // If the largest block was the only block, we are done.
      if (ranges.size() == 1) {
        *result_slot_index = index;
        return offset;
      }

      // Found an offset where the largest range fits. Now match the
      // remaining ones.
      int displacement = MatchRemaining(offset, ranges, index);

      // Displacement is either 0 for a match, or a minimum distance to where
      // a potential match can happen.
      if (displacement == 0) {
        *result_slot_index = index;
        return offset;
      }

      start += displacement;
    }

    // TODO(ajohnsen): Perhaps check if start > end and move it accordingly
    // (to avoid min_start).
    min_start = start;

    index++;
  }

  const Range slot = free_slots_[index];
  ASSERT(slot.end() == INT_MAX);

  // If we are at end, we know it fits.
  int offset = Utils::Maximum(0, slot.begin() - min_row_index);
  // Pad to guarantee unique offsets.
  while (used_offsets_.Count(offset) > 0) {
    offset++;
  }

  *result_slot_index = index;
  return offset;
}

int RowFitter::MatchRemaining(int offset,
                              const Range::List& ranges,
                              size_t slot_index) {
  size_t index = 1;
  size_t length = ranges.size();

  // Start by back-tracking, as second range may be before the largest.
  slot_index = MoveBackToCover(ranges[index].WithOffset(offset), slot_index);

  for (; index < length; index++) {
    const Range range = ranges[index].WithOffset(offset);

    slot_index = MoveForwardToCover(range, slot_index);
    const Range slot = free_slots_[slot_index];

    if (range.begin() < slot.begin()) return slot.begin() - range.begin();
  }

  return 0;
}

size_t RowFitter::MoveBackToCover(const Range range, size_t slot_index) {
  while (slot_index > 0 && range.IsBefore(free_slots_[slot_index])) {
    slot_index--;
  }
  return slot_index;
}

size_t RowFitter::MoveForwardToCover(const Range range, size_t slot_index) {
  while (free_slots_[slot_index].end() < range.end()) slot_index++;
  return slot_index;
}

void RowFitter::UpdateFreeSlots(int offset,
                                const Range::List& ranges,
                                size_t slot_index) {
  for (size_t i = 0; i < ranges.size(); i++) {
    ASSERT(slot_index < free_slots_.size());
    const Range range = ranges[i].WithOffset(offset);

    if (i > 0) {
      if (i == 1) {
        while (free_slots_[slot_index].IsAfter(range)) {
          ASSERT(slot_index > 0);
          slot_index--;
        }
      }

      slot_index = MoveForwardToCover(range, slot_index);
    }

    // Assert that we have a valid slot.
    ASSERT(slot_index < free_slots_.size());
    ASSERT(free_slots_[slot_index].begin() < range.end());

    slot_index = FitInFreeSlot(range, slot_index);
  }

  for (size_t i = 0; i < free_slots_.size(); i++) {
    ASSERT(free_slots_[i].begin() < free_slots_[i].end());
  }
}

size_t RowFitter::FitInFreeSlot(const Range range, size_t slot_index) {
  Range& slot = free_slots_[slot_index];
  ASSERT(slot.Contains(range));
  if (slot.begin() < range.begin()) {
    if (slot.end() > range.end()) {
      free_slots_.Insert(slot_index, Range(slot.begin(), range.begin()));
      slot_index++;
      free_slots_[slot_index].set_begin(range.end());
    } else {
      slot.set_end(range.begin());
      slot_index++;
    }
  } else if (slot.end() <= range.end()) {
    ASSERT(slot.IsSame(range));
    free_slots_.Remove(slot_index);
  } else {
    slot.set_begin(range.end());
  }
  return slot_index;
}

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING
