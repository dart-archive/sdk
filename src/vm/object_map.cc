// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/object_map.h"

namespace fletch {

ObjectMap::ObjectMap(int capacity) {
  table_by_id_ = NewTable(Utils::Maximum(capacity, 8));
  size_ = 0;
  ASSERT(!HasTableByObject());
}

ObjectMap::~ObjectMap() {
  DeleteTable(table_by_id_);
  DeleteTable(table_by_object_);
}

void ObjectMap::Add(int64 id, Object* object) {
  int index = BucketIndexFromId(id);
  Bucket* original = table_by_id_[index];
  Bucket* current = original;
  while (current != NULL) {
    if (current->id == id) {
      if (HasTableByObject() && current->object != object) {
        Bucket* existing = DetachByObject(current->object);
        ASSERT(existing != NULL);
        int index = BucketIndexFromObject(object);
        existing->next = table_by_object_[index];
        existing->object = object;
        table_by_object_[index] = existing;
      }
      current->object = object;
      return;
    }
    current = current->next;
  }

  // Expand the size and recompute the bucket index if necessary.
  if (Expand()) index = BucketIndexFromId(id);

  // Add to the bucket list.
  Bucket* bucket = new Bucket();
  bucket->next = original;
  bucket->id = id;
  bucket->object = object;
  table_by_id_[index] = bucket;
  if (HasTableByObject()) AddToTableByObject(id, object);
}

bool ObjectMap::RemoveById(int64 id) {
  Bucket* bucket = DetachById(id);
  if (bucket == NULL) return false;
  if (HasTableByObject()) delete DetachByObject(bucket->object);
  delete bucket;
  size_--;
  return true;
}

bool ObjectMap::RemoveByObject(Object* object) {
  PopulateTableByObject();
  Bucket* bucket = DetachByObject(object);
  if (bucket == NULL) return false;
  delete DetachById(bucket->id);
  delete bucket;
  size_--;
  return true;
}

Object* ObjectMap::LookupById(int64 id, bool* entry_exists) {
  int index = BucketIndexFromId(id);
  Bucket* current = table_by_id_[index];
  while (current != NULL) {
    if (current->id == id) {
      if (entry_exists != NULL) *entry_exists = true;
      return current->object;
    }
    current = current->next;
  }
  if (entry_exists != NULL) *entry_exists = false;
  return NULL;
}

int64 ObjectMap::LookupByObject(Object* object, int64 none) {
  PopulateTableByObject();
  int index = BucketIndexFromObject(object);
  Bucket* current = table_by_object_[index];
  while (current != NULL) {
    if (current->object == object) return current->id;
    current = current->next;
  }
  return none;
}

void ObjectMap::ClearTableByObject() {
  DeleteTable(table_by_object_);
  table_by_object_ = List<Bucket*>();
  ASSERT(!HasTableByObject());
}

void ObjectMap::IteratePointers(PointerVisitor* visitor) {
  ASSERT(!HasTableByObject());
  for (int i = 0; i < table_by_id_.length(); i++) {
    Bucket* current = table_by_id_[i];
    while (current != NULL) {
      visitor->Visit(&current->object);
      current = current->next;
    }
  }
}

int ObjectMap::BucketIndexFromId(int64 id) {
  return id & (table_by_id_.length() - 1);
}

int ObjectMap::BucketIndexFromObject(Object* object) {
  ASSERT(HasTableByObject());
  return reinterpret_cast<word>(object) & (table_by_object_.length() - 1);
}

ObjectMap::Bucket* ObjectMap::DetachById(int64 id) {
  int index = BucketIndexFromId(id);
  Bucket* previous = NULL;
  Bucket* current = table_by_id_[index];
  while (current != NULL) {
    if (current->id == id) {
      Bucket* next = current->next;
      if (previous == NULL) {
        table_by_id_[index] = next;
      } else {
        previous->next = next;
      }
      return current;
    }
    previous = current;
    current = current->next;
  }
  return NULL;
}

ObjectMap::Bucket* ObjectMap::DetachByObject(Object* object) {
  int index = BucketIndexFromObject(object);
  Bucket* previous = NULL;
  Bucket* current = table_by_object_[index];
  while (current != NULL) {
    if (current->object == object) {
      Bucket* next = current->next;
      if (previous == NULL) {
        table_by_object_[index] = next;
      } else {
        previous->next = next;
      }
      return current;
    }
    previous = current;
    current = current->next;
  }
  return NULL;
}

void ObjectMap::AddToTableByObject(int64 id, Object* object) {
  ASSERT(HasTableByObject());
  int index = BucketIndexFromObject(object);
  Bucket* bucket = new Bucket();
  bucket->next = table_by_object_[index];
  bucket->id = id;
  bucket->object = object;
  table_by_object_[index] = bucket;
}

bool ObjectMap::Expand() {
  int needed = (++size_) << 1;
  if (needed < table_by_id_.length()) return false;

  // Clear the object -> id mapping table and allocate
  // a new and large table for the id -> object mappings.
  ClearTableByObject();
  List<Bucket*> old_table_by_id = table_by_id_;
  table_by_id_ = NewTable(needed << 1);

  // Run through the old mappings and re-use the buckets
  // in the new table after rehashing.
  for (int i = 0; i < old_table_by_id.length(); i++) {
    Bucket* current = old_table_by_id[i];
    while (current != NULL) {
      Bucket* next = current->next;
      int index = BucketIndexFromId(current->id);
      current->next = table_by_id_[index];
      table_by_id_[index] = current;
      current = next;
    }
  }

  // Delete the old table.
  old_table_by_id.Delete();
  return true;
}

void ObjectMap::PopulateTableByObject() {
  if (HasTableByObject()) return;
  table_by_object_ = NewTable(table_by_id_.length());
  for (int i = 0; i < table_by_id_.length(); i++) {
    Bucket* current = table_by_id_[i];
    while (current != NULL) {
      AddToTableByObject(current->id, current->object);
      current = current->next;
    }
  }
  ASSERT(HasTableByObject());
}

List<ObjectMap::Bucket*> ObjectMap::NewTable(int length) {
  List<Bucket*> result = List<Bucket*>::New(length);
  memset(result.data(), 0, length * kPointerSize);
  return result;
}

void ObjectMap::DeleteTable(List<Bucket*> table) {
  for (int i = 0; i < table.length(); i++) {
    Bucket* current = table[i];
    while (current != NULL) {
      Bucket* next = current->next;
      delete current;
      current = next;
    }
  }
  table.Delete();
}

}  // namespace fletch
