// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_OBJECT_MAP_H_
#define SRC_VM_OBJECT_MAP_H_

#include "src/vm/object.h"
#include "src/shared/globals.h"

namespace dartino {

class ObjectMap {
 public:
  explicit ObjectMap(int capacity);
  virtual ~ObjectMap();

  uword size() const { return size_; }

  void Add(int64 id, Object* object);

  bool RemoveById(int64 id);
  bool RemoveByObject(Object* object);

  Object* LookupById(int64 id, bool* entry_exists = NULL);
  int64 LookupByObject(Object* object, int64 none = -1);

  bool HasTableByObject() const { return !table_by_object_.is_empty(); }
  void ClearTableByObject();

  void IteratePointers(PointerVisitor* visitor);

 private:
  struct Bucket {
    Bucket* next;
    int64 id;
    Object* object;
  };

  List<Bucket*> table_by_id_;
  List<Bucket*> table_by_object_;
  uword size_;

  int BucketIndexFromId(int64 id);
  int BucketIndexFromObject(Object* object);

  Bucket* DetachById(int64 id);
  Bucket* DetachByObject(Object* object);

  void AddToTableByObject(int64 id, Object* object);

  bool Expand();

  void PopulateTableByObject();

  static List<Bucket*> NewTable(int length);
  static void DeleteTable(List<Bucket*> table);
};

}  // namespace dartino

#endif  // SRC_VM_OBJECT_MAP_H_
