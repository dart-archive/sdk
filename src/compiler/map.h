// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_MAP_H_
#define SRC_COMPILER_MAP_H_

#include "src/compiler/list.h"
#include "src/compiler/list_builder.h"
#include "src/compiler/zone.h"

namespace fletch {

template<typename V>
class IdMap : public ZoneAllocated {
 public:
  IdMap(Zone* zone, int n);

  Zone* zone() const { return zone_; }
  int size() const { return size_; }
  bool is_empty() const { return size_ == 0; }

  void Add(int key, V value);

  bool Contains(int key) const;
  V Lookup(int key) const;

  void Clear();
  void Resize();

  List<V> ToList() const;
  template<int C>
  void AddToListBuilder(ListBuilder<V, C>* builder) const;

 protected:
  struct Slot {
    int id;
    V value;
  };

  Zone* const zone_;
  int size_;
  List<Slot> table_;
};

template<typename V>
IdMap<V>::IdMap(Zone* zone, int n)
    : zone_(zone)
    , size_(0)
    , table_(List<Slot>::New(zone, Utils::RoundUpToPowerOfTwo((n + 1) << 1))) {
  Clear();
}

template<typename V>
void IdMap<V>::Add(int id, V value) {
  ASSERT(!Contains(id));
  int capacity = table_.length();
  if (size_ >= (capacity >> 1)) {
    Resize();
    capacity = table_.length();
  }
  ASSERT(Utils::IsPowerOfTwo(capacity));
  int index = id & (capacity - 1);
  for (int step = 1; true; step++) {
    int probe = table_[index].id;
    if (probe == -1) {
      table_[index].id = id;
      table_[index].value = value;
      size_++;
      return;
    }
    index = (index + step) & (capacity - 1);
  }
}

template<typename V>
bool IdMap<V>::Contains(int id) const {
  int capacity = table_.length();
  ASSERT(Utils::IsPowerOfTwo(capacity));
  int index = id & (capacity - 1);
  for (int step = 1; true; step++) {
    int probe = table_[index].id;
    if (probe == id) {
      return true;
    } else if (probe == -1) {
      return false;
    }
    index = (index + step) & (capacity - 1);
  }
  return false;
}

template<typename V>
V IdMap<V>::Lookup(int id) const {
  int capacity = table_.length();
  ASSERT(Utils::IsPowerOfTwo(capacity));
  int index = id & (capacity - 1);
  for (int step = 1; true; step++) {
    int probe = table_[index].id;
    if (probe == id) {
      return table_[index].value;
    } else if (probe == -1) {
      return V();
    }
    index = (index + step) & (capacity - 1);
  }
  return V();
}

template<typename V>
void IdMap<V>::Clear() {
  for (int i = 0; i < table_.length(); i++) {
    table_[i].id = -1;
  }
  size_ = 0;
}

template<typename V>
void IdMap<V>::Resize() {
  List<Slot> old = table_;
  table_ = List<Slot>::New(zone(), old.length() << 1);
  Clear();
  for (int i = 0; i < old.length(); i++) {
    int id = old[i].id;
    if (id != -1) Add(id, old[i].value);
  }
}

template<typename V>
List<V> IdMap<V>::ToList() const {
  List<V> list = List<V>::New(zone(), size());
  int index = 0;
  for (int i = 0; i < table_.length(); i++) {
    Slot slot = table_[i];
    if (slot.id != -1) list[index++] = slot.value;
  }
  ASSERT(index == size());
  return list;
}

template<typename V> template<int C>
void IdMap<V>::AddToListBuilder(ListBuilder<V, C>* builder) const {
  for (int i = 0; i < table_.length(); i++) {
    Slot slot = table_[i];
    if (slot.id != -1) builder->Add(slot.value);
  }
}

template<typename K>
struct MapUtils {
  typedef bool (*Compare)(K, K);
  typedef int (*Hash)(K);
};

template<typename K,
         typename V,
         typename MapUtils<K>::Hash Hash,
         typename MapUtils<K>::Compare Compare>
class Map : public ZoneAllocated {
 public:
  Map(Zone* zone, int n)
      : zone_(zone)
      , size_(0)
      , table_(List<Bucket>::New(
            zone, Utils::RoundUpToPowerOfTwo((n + 1) << 1))) {
    Clear();
  }

  Zone* zone() const { return zone_; }
  int size() const { return size_; }

  void Add(K key, V value) {
    ASSERT(Lookup(key) == V());  // Cannot be used to replace.
    int hash = Hash(key);
    int capacity = table_.length();
    if (size_ >= (capacity >> 1)) {
      Resize();
      capacity = table_.length();
    }
    ASSERT(Utils::IsPowerOfTwo(capacity));
    int index = hash & (capacity - 1);
    for (int step = 1; true; step++) {
      int probe = table_[index].hash;
      if (probe == hash) {
        table_[index].next = new(zone()) Slot(key, value, table_[index].next);
        return;
      } else if (probe == -1) {
        table_[index].hash = hash;
        table_[index].next = new(zone()) Slot(key, value, NULL);
        size_++;
        return;
      }
      index = (index + step) & (capacity - 1);
    }
  }

  bool Contains(K key) const {
    int hash = Hash(key);
    int capacity = table_.length();
    ASSERT(Utils::IsPowerOfTwo(capacity));
    int index = hash & (capacity - 1);
    for (int step = 1; true; step++) {
      int probe = table_[index].hash;
      if (probe == hash) {
        Slot* current = table_[index].next;
        do {
          if (Compare(current->key, key)) return true;
          current = current->next;
        } while (current != NULL);
        return false;
      } else if (probe == -1) {
        return false;
      }
      index = (index + step) & (capacity - 1);
    }
    return false;
  }

  V Lookup(K key) {
    int hash = Hash(key);
    int capacity = table_.length();
    ASSERT(Utils::IsPowerOfTwo(capacity));
    int index = hash & (capacity - 1);
    for (int step = 1; true; step++) {
      int probe = table_[index].hash;
      if (probe == hash) {
        Slot* current = table_[index].next;
        do {
          if (Compare(current->key, key)) return current->value;
          current = current->next;
        } while (current != NULL);
        return V();
      } else if (probe == -1) {
        return V();
      }
      index = (index + step) & (capacity - 1);
    }
    return V();
  }

  void Clear() {
    for (int i = 0; i < table_.length(); i++) {
      table_[i].hash = -1;
    }
    size_ = 0;
  }

  void Resize() {
    List<Bucket> old = table_;
    table_ = List<Bucket>::New(zone(), old.length() << 1);
    Clear();
    for (int i = 0; i < old.length(); i++) {
      int hash = old[i].hash;
      if (hash != -1) Add(hash, old[i].next);
    }
  }

 protected:
  struct Slot : ZoneAllocated {
    Slot(K key, V value, Slot* next)
        : key(key), value(value), next(next) {}
    K key;
    V value;
    Slot* next;
  };

  struct Bucket {
    int hash;
    Slot* next;
  };

  void Add(int hash, Slot* slot) {
    int capacity = table_.length();
    ASSERT(Utils::IsPowerOfTwo(capacity));
    int index = hash & (capacity - 1);
    for (int step = 1; true; step++) {
      int probe = table_[index].hash;
      ASSERT(probe != hash);
      if (probe == -1) {
        table_[index].hash = hash;
        table_[index].next = slot;
        size_++;
        return;
      }
      index = (index + step) & (capacity - 1);
    }
  }

  Zone* const zone_;
  int size_;
  List<Bucket> table_;
};

int MapStringHash(const char* value);

bool MapStringCompare(const char* a, const char* b);

template<typename V>
class StringMap : public Map<const char*, V, MapStringHash, MapStringCompare> {
 public:
  StringMap(Zone* zone, int n)
      : Map<const char*, V, MapStringHash, MapStringCompare>(zone, n) {
  }
};

template<typename K>
int MapPointerHash(const K value) {
  return reinterpret_cast<intptr_t>(value) >> 3;
}

template<typename K>
bool MapPointerCompare(const K a, const K b) {
  return a == b;
}

template<typename K, typename V>
class PointerMap : public Map<K, V, MapPointerHash, MapPointerCompare> {
 public:
  PointerMap(Zone* zone, int n)
      : Map<K, V, MapPointerHash, MapPointerCompare>(zone, n) {
  }
};

int MapIntegerHash(const int64 value);

bool MapIntegerCompare(const int64 a, const int64 b);

template<typename V>
class IntegerMap : public Map<int64, V, MapIntegerHash, MapIntegerCompare> {
 public:
  IntegerMap(Zone* zone, int n)
      : Map<int64, V, MapIntegerHash, MapIntegerCompare>(zone, n) {
  }
};

}  // namespace fletch

#endif  // SRC_COMPILER_MAP_H_

