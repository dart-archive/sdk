// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:_fletch_system' as fletch;

const patch = "patch";

@patch class HashMap<K, V> {
  @patch factory HashMap({ bool equals(K key1, K key2),
                           int hashCode(K key),
                           bool isValidKey(potentialKey) }) {
    if (isValidKey == null) {
      if (hashCode == null) {
        if (equals == null) {
          return new _HashMap<K, V>();
        }
        hashCode = _defaultHashCode;
      } else {
        if (identical(identityHashCode, hashCode) &&
            identical(identical, equals)) {
          return new _IdentityHashMap<K, V>();
        }
        if (equals == null) {
          equals = _defaultEquals;
        }
      }
    } else {
      if (hashCode == null) {
        hashCode = _defaultHashCode;
      }
      if (equals == null) {
        equals = _defaultEquals;
      }
    }
    return new _CustomHashMap<K, V>(equals, hashCode, isValidKey);
  }

  @patch factory HashMap.identity() = _IdentityHashMap<K, V>;
}

const int _MODIFICATION_COUNT_MASK = 0x3fffffff;

class _HashMap<K, V> implements HashMap<K, V> {
  static const int _INITIAL_CAPACITY = 8;


  int _elementCount = 0;
  List<_HashMapEntry> _buckets = new List(_INITIAL_CAPACITY);
  int _modificationCount = 0;

  int get length => _elementCount;
  bool get isEmpty => _elementCount == 0;
  bool get isNotEmpty => _elementCount != 0;

  Iterable<K> get keys => new _HashMapKeyIterable<K>(this);
  Iterable<V> get values => new _HashMapValueIterable<V>(this);

  bool containsKey(Object key) {
    int hashCode = key.hashCode;
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && entry.key == key) return true;
      entry = entry.next;
    }
    return false;
  }

  bool containsValue(Object value) {
    List buckets = _buckets;
    int length = buckets.length;
    for (int i = 0; i < length; i++) {
      _HashMapEntry entry = buckets[i];
      while (entry != null) {
        if (entry.value == value) return true;
        entry = entry.next;
      }
    }
    return false;
  }

  V operator[](Object key) {
    int hashCode = key.hashCode;
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && entry.key == key) {
        return entry.value;
      }
      entry = entry.next;
    }
    return null;
  }

  void operator []=(K key, V value) {
    int hashCode = key.hashCode;
    List buckets = _buckets;
    int length = buckets.length;
    int index = hashCode & (length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && entry.key == key) {
        entry.value = value;
        return;
      }
      entry = entry.next;
    }
    _addEntry(buckets, index, length, key, value, hashCode);
  }

  V putIfAbsent(K key, V ifAbsent()) {
    int hashCode = key.hashCode;
    List buckets = _buckets;
    int length = buckets.length;
    int index = hashCode & (length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && entry.key == key) {
        return entry.value;
      }
      entry = entry.next;
    }
    int stamp = _modificationCount;
    V value = ifAbsent();
    if (stamp == _modificationCount) {
      _addEntry(buckets, index, length, key, value, hashCode);
    } else {
      this[key] = value;
    }
    return value;
  }

  void addAll(Map<K, V> other) {
    other.forEach((K key, V value) {
      this[key] = value;
    });
  }

  void forEach(void action(K key, V value)) {
    int stamp = _modificationCount;
    List buckets = _buckets;
    int length = buckets.length;
    for (int i = 0; i < length; i++) {
      _HashMapEntry entry = buckets[i];
      while (entry != null) {
        action(entry.key, entry.value);
        if (stamp != _modificationCount) {
          throw new ConcurrentModificationError(this);
        }
        entry = entry.next;
      }
    }
  }

  V remove(Object key) {
    int hashCode = key.hashCode;
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    _HashMapEntry previous = null;
    while (entry != null) {
      _HashMapEntry next = entry.next;
      if (hashCode == entry.hashCode && entry.key == key) {
        _removeEntry(entry, previous, index);
        _elementCount--;
        _modificationCount =
            (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
        return entry.value;
      }
      previous = entry;
      entry = next;
    }
    return null;
  }

  void clear() {
    _buckets = new List(_INITIAL_CAPACITY);
    if (_elementCount > 0) {
      _elementCount = 0;
      _modificationCount = (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
    }
  }

  void _removeEntry(_HashMapEntry entry,
                    _HashMapEntry previousInBucket,
                    int bucketIndex) {
    if (previousInBucket == null) {
      _buckets[bucketIndex] = entry.next;
    } else {
      previousInBucket.next = entry.next;
    }
  }

  void _addEntry(List buckets, int index, int length,
                 K key, V value, int hashCode) {
    _HashMapEntry entry =
        new _HashMapEntry(key, value, hashCode, buckets[index]);
    buckets[index] = entry;
    int newElements = _elementCount + 1;
    _elementCount = newElements;
    // If we end up with more than 75% non-empty entries, we
    // resize the backing store.
    if ((newElements << 2) > ((length << 1) + length)) _resize();
    _modificationCount = (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
  }

  void _resize() {
    List oldBuckets = _buckets;
    int oldLength = oldBuckets.length;
    int newLength = oldLength << 1;
    List newBuckets = new List(newLength);
    for (int i = 0; i < oldLength; i++) {
      _HashMapEntry entry = oldBuckets[i];
      while (entry != null) {
        _HashMapEntry next = entry.next;
        int hashCode = entry.hashCode;
        int index = hashCode & (newLength - 1);
        entry.next = newBuckets[index];
        newBuckets[index] = entry;
        entry = next;
      }
    }
    _buckets = newBuckets;
  }

  String toString() => Maps.mapToString(this);

  Set<K> _newKeySet() => new _HashSet<K>();
}

// TODO(ajohnsen): Use _TypeTest<E>.test when 'is E' is implemented.
bool _defaultTypeTest(v) => true;

class _CustomHashMap<K, V> extends _HashMap<K, V> {
  final _Equality<K> _equals;
  final _Hasher<K> _hashCode;
  final _Predicate _validKey;
  _CustomHashMap(this._equals, this._hashCode, validKey)
      : _validKey = (validKey != null) ? validKey : _defaultTypeTest;


  bool containsKey(Object key) {
    if (!_validKey(key)) return false;
    int hashCode = _hashCode(key);
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && _equals(entry.key, key)) return true;
      entry = entry.next;
    }
    return false;
  }

  V operator[](Object key) {
    if (!_validKey(key)) return null;
    int hashCode = _hashCode(key);
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && _equals(entry.key, key)) {
        return entry.value;
      }
      entry = entry.next;
    }
    return null;
  }

  void operator []=(K key, V value) {
    int hashCode = _hashCode(key);
    List buckets = _buckets;
    int length = buckets.length;
    int index = hashCode & (length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && _equals(entry.key, key)) {
        entry.value = value;
        return;
      }
      entry = entry.next;
    }
    _addEntry(buckets, index, length, key, value, hashCode);
  }

  V putIfAbsent(K key, V ifAbsent()) {
    int hashCode = _hashCode(key);
    List buckets = _buckets;
    int length = buckets.length;
    int index = hashCode & (length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && _equals(entry.key, key)) {
        return entry.value;
      }
      entry = entry.next;
    }
    int stamp = _modificationCount;
    V value = ifAbsent();
    if (stamp == _modificationCount) {
      _addEntry(buckets, index, length, key, value, hashCode);
    } else {
      this[key] = value;
    }
    return value;
  }

  V remove(Object key) {
    if (!_validKey(key)) return null;
    int hashCode = _hashCode(key);
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    _HashMapEntry previous = null;
    while (entry != null) {
      _HashMapEntry next = entry.next;
      if (hashCode == entry.hashCode && _equals(entry.key, key)) {
        _removeEntry(entry, previous, index);
        _elementCount--;
        _modificationCount =
            (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
        return entry.value;
      }
      previous = entry;
      entry = next;
    }
    return null;
  }

  String toString() => Maps.mapToString(this);

  Set<K> _newKeySet() => new _CustomHashSet<K>(_equals, _hashCode, _validKey);
}

class _IdentityHashMap<K, V> extends _HashMap<K, V> {

  bool containsKey(Object key) {
    int hashCode = identityHashCode(key);
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && identical(entry.key, key)) return true;
      entry = entry.next;
    }
    return false;
  }

  V operator[](Object key) {
    int hashCode = identityHashCode(key);
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && identical(entry.key, key)) {
        return entry.value;
      }
      entry = entry.next;
    }
    return null;
  }

  void operator []=(K key, V value) {
    int hashCode = identityHashCode(key);
    List buckets = _buckets;
    int length = buckets.length;
    int index = hashCode & (length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && identical(entry.key, key)) {
        entry.value = value;
        return;
      }
      entry = entry.next;
    }
    _addEntry(buckets, index, length, key, value, hashCode);
  }

  V putIfAbsent(K key, V ifAbsent()) {
    int hashCode = identityHashCode(key);
    List buckets = _buckets;
    int length = buckets.length;
    int index = hashCode & (length - 1);
    _HashMapEntry entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && identical(entry.key, key)) {
        return entry.value;
      }
      entry = entry.next;
    }
    int stamp = _modificationCount;
    V value = ifAbsent();
    if (stamp == _modificationCount) {
      _addEntry(buckets, index, length, key, value, hashCode);
    } else {
      this[key] = value;
    }
    return value;
  }

  V remove(Object key) {
    int hashCode = identityHashCode(key);
    List buckets = _buckets;
    int index = hashCode & (buckets.length - 1);
    _HashMapEntry entry = buckets[index];
    _HashMapEntry previous = null;
    while (entry != null) {
      _HashMapEntry next = entry.next;
      if (hashCode == entry.hashCode && identical(entry.key, key)) {
        _removeEntry(entry, previous, index);
        _elementCount--;
        _modificationCount =
            (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
        return entry.value;
      }
      previous = entry;
      entry = next;
    }
    return null;
  }

  String toString() => Maps.mapToString(this);

  Set<K> _newKeySet() => new _IdentityHashSet<K>();
}


class _HashMapEntry {
  final key;
  var value;
  final int hashCode;
  _HashMapEntry next;
  _HashMapEntry(this.key, this.value, this.hashCode, this.next);
}

abstract class _HashMapIterable<E> extends Iterable<E>
                                   implements EfficientLength {
  final _HashMap _map;
  _HashMapIterable(this._map);
  int get length => _map.length;
  bool get isEmpty => _map.isEmpty;
  bool get isNotEmpty => _map.isNotEmpty;
}

class _HashMapKeyIterable<K> extends _HashMapIterable<K> {
  _HashMapKeyIterable(_HashMap map) : super(map);
  Iterator<K> get iterator => new _HashMapKeyIterator<K>(_map);
  bool contains(Object key) => _map.containsKey(key);
  void forEach(void action(K key)) {
    _map.forEach((K key, _) {
      action(key);
    });
  }
  Set<K> toSet() => _map._newKeySet()..addAll(this);
}

class _HashMapValueIterable<V> extends _HashMapIterable<V> {
  _HashMapValueIterable(HashMap map) : super(map);
  Iterator<V> get iterator => new _HashMapValueIterator<V>(_map);
  bool contains(Object value) => _map.containsValue(value);
  void forEach(void action(V value)) {
    _map.forEach((_, V value) {
      action(value);
    });
  }
}

abstract class _HashMapIterator<E> implements Iterator<E> {
  final _HashMap _map;
  final int _stamp;

  int _index = 0;
  _HashMapEntry _entry;

  _HashMapIterator(_HashMap map)
     : _map = map, _stamp = map._modificationCount;

  bool moveNext() {
    if (_stamp != _map._modificationCount) {
      throw new ConcurrentModificationError(_map);
    }
    _HashMapEntry entry = _entry;
    if (entry != null) {
      _HashMapEntry next = entry.next;
      if (next != null) {
        _entry = next;
        return true;
      }
      _entry = null;
    }
    List buckets = _map._buckets;
    int length = buckets.length;
    for (int i = _index; i < length; i++) {
      entry = buckets[i];
      if (entry != null) {
        _index = i + 1;
        _entry = entry;
        return true;
      }
    }
    _index = length;
    return false;
  }
}

class _HashMapKeyIterator<K> extends _HashMapIterator<K> {
  _HashMapKeyIterator(HashMap map) : super(map);
  K get current {
    _HashMapEntry entry = _entry;
    return (entry == null) ? null : entry.key;
  }
}

class _HashMapValueIterator<V> extends _HashMapIterator<V> {
  _HashMapValueIterator(HashMap map) : super(map);
  V get current {
    _HashMapEntry entry = _entry;
    return (entry == null) ? null : entry.value;
  }
}

@patch class LinkedHashMap<K, V> {
  @patch factory LinkedHashMap({ bool equals(K key1, K key2),
                                 int hashCode(K key),
                                 bool isValidKey(potentialKey) }) {
    if (isValidKey == null) {
      if (hashCode == null) {
        if (equals == null) {
          return new _CompactLinkedHashMap<K, V>();
        }
        hashCode = _defaultHashCode;
      } else {
        if (identical(identityHashCode, hashCode) &&
            identical(identical, equals)) {
          return new _CompactLinkedIdentityHashMap<K, V>();
        }
        if (equals == null) {
          equals = _defaultEquals;
        }
      }
    } else {
      if (hashCode == null) {
        hashCode = _defaultHashCode;
      }
      if (equals == null) {
        equals = _defaultEquals;
      }
    }
    return new _CompactLinkedCustomHashMap<K, V>(equals, hashCode, isValidKey);
  }

  @patch factory LinkedHashMap.identity() =
      _CompactLinkedIdentityHashMap<K, V>;
}

@patch class LinkedHashSet<E> {
  @patch factory LinkedHashSet({ bool equals(E key1, E key2),
                                 int hashCode(E key),
                                 bool isValidKey(potentialKey) }) {
    if (isValidKey == null) {
      if (hashCode == null) {
        if (equals == null) {
          return new _CompactLinkedHashSet<E>();
        }
        hashCode = _defaultHashCode;
      } else {
        if (identical(identityHashCode, hashCode) &&
            identical(identical, equals)) {
          return new _CompactLinkedIdentityHashSet<E>();
        }
        if (equals == null) {
          equals = _defaultEquals;
        }
      }
    } else {
      if (hashCode == null) {
        hashCode = _defaultHashCode;
      }
      if (equals == null) {
        equals = _defaultEquals;
      }
    }
    return new _CompactLinkedCustomHashSet<E>(equals, hashCode, isValidKey);
  }

  @patch factory LinkedHashSet.identity() = _CompactLinkedIdentityHashSet<E>;
}

@patch class HashSet<E> {
  @patch factory HashSet({ bool equals(E key1, E key2),
                           int hashCode(E key),
                           bool isValidKey(potentialKey) }) {
    if (isValidKey == null) {
      if (hashCode == null) {
        if (equals == null) {
          return new _HashSet<E>();
        }
        hashCode = _defaultHashCode;
      } else {
        if (identical(identityHashCode, hashCode) &&
            identical(identical, equals)) {
          return new _IdentityHashSet<E>();
        }
        if (equals == null) {
          equals = _defaultEquals;
        }
      }
    } else {
      if (hashCode == null) {
        hashCode = _defaultHashCode;
      }
      if (equals == null) {
        equals = _defaultEquals;
      }
    }
    return new _CustomHashSet<E>(equals, hashCode, isValidKey);
  }

  @patch factory HashSet.identity() = _IdentityHashSet<E>;
}

class _HashSet<E> extends _HashSetBase<E> implements HashSet<E> {
  static const int _INITIAL_CAPACITY = 8;

  List<_HashSetEntry> _buckets = new List(_INITIAL_CAPACITY);
  int _elementCount = 0;
  int _modificationCount = 0;

  bool _equals(e1, e2) => e1 == e2;
  int _hashCode(e) => e.hashCode;

  // Iterable.

  Iterator<E> get iterator => new _HashSetIterator<E>(this);

  int get length => _elementCount;

  bool get isEmpty => _elementCount == 0;

  bool get isNotEmpty => _elementCount != 0;

  bool contains(Object object) {
    int index = _hashCode(object) & (_buckets.length - 1);
    _HashSetEntry entry = _buckets[index];
    while (entry != null) {
      if (_equals(entry.key, object)) return true;
      entry = entry.next;
    }
    return false;
  }

  E lookup(Object object) {
    int index = _hashCode(object) & (_buckets.length - 1);
    _HashSetEntry entry = _buckets[index];
    while (entry != null) {
      var key = entry.key;
      if (_equals(key, object)) return key;
      entry = entry.next;
    }
    return null;
  }

  // Set.

  bool add(E element) {
    int hashCode = _hashCode(element);
    int index = hashCode & (_buckets.length - 1);
    _HashSetEntry entry = _buckets[index];
    while (entry != null) {
      if (_equals(entry.key, element)) return false;
      entry = entry.next;
    }
    _addEntry(element, hashCode, index);
    return true;
  }

  void addAll(Iterable<E> objects) {
    int ctr = 0;
    for (E object in objects) {
      ctr++;
      add(object);
    }
  }

  bool _remove(Object object, int hashCode) {
    int index = hashCode & (_buckets.length - 1);
    _HashSetEntry entry = _buckets[index];
    _HashSetEntry previous = null;
    while (entry != null) {
      if (_equals(entry.key, object)) {
        _HashSetEntry next = entry.remove();
        if (previous == null) {
          _buckets[index] = next;
        } else {
          previous.next = next;
        }
        _elementCount--;
        _modificationCount =
            (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
        return true;
      }
      previous = entry;
      entry = entry.next;
    }
    return false;
  }

  bool remove(Object object) => _remove(object, _hashCode(object));

  void removeAll(Iterable<Object> objectsToRemove) {
    for (Object object in objectsToRemove) {
      _remove(object, _hashCode(object));
    }
  }

  void _filterWhere(bool test(E element), bool removeMatching) {
    int length = _buckets.length;
    for (int index =  0; index < length; index++) {
      _HashSetEntry entry = _buckets[index];
      _HashSetEntry previous = null;
      while (entry != null) {
        int modificationCount = _modificationCount;
        bool testResult = test(entry.key);
        if (modificationCount != _modificationCount) {
          throw new ConcurrentModificationError(this);
        }
        if (testResult == removeMatching) {
          _HashSetEntry next = entry.remove();
          if (previous == null) {
            _buckets[index] = next;
          } else {
            previous.next = next;
          }
          _elementCount--;
          _modificationCount =
              (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
          entry = next;
        } else {
          previous = entry;
          entry = entry.next;
        }
      }
    }
  }

  void removeWhere(bool test(E element)) {
    _filterWhere(test, true);
  }

  void retainWhere(bool test(E element)) {
    _filterWhere(test, false);
  }

  void clear() {
    _buckets = new List(_INITIAL_CAPACITY);
    if (_elementCount > 0) {
      _elementCount = 0;
      _modificationCount = (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
    }
  }

  void _addEntry(E key, int hashCode, int index) {
    _buckets[index] = new _HashSetEntry(key, hashCode, _buckets[index]);
    int newElements = _elementCount + 1;
    _elementCount = newElements;
    int length = _buckets.length;
    // If we end up with more than 75% non-empty entries, we
    // resize the backing store.
    if ((newElements << 2) > ((length << 1) + length)) _resize();
    _modificationCount = (_modificationCount + 1) & _MODIFICATION_COUNT_MASK;
  }

  void _resize() {
    int oldLength = _buckets.length;
    int newLength = oldLength << 1;
    List oldBuckets = _buckets;
    List newBuckets = new List(newLength);
    for (int i = 0; i < oldLength; i++) {
      _HashSetEntry entry = oldBuckets[i];
      while (entry != null) {
        _HashSetEntry next = entry.next;
        int newIndex = entry.hashCode & (newLength - 1);
        entry.next = newBuckets[newIndex];
        newBuckets[newIndex] = entry;
        entry = next;
      }
    }
    _buckets = newBuckets;
  }

  HashSet<E> _newSet() => new _HashSet<E>();
}

class _IdentityHashSet<E> extends _HashSet<E> {
  int _hashCode(e) => identityHashCode(e);
  bool _equals(e1, e2) => identical(e1, e2);
  HashSet<E> _newSet() => new _IdentityHashSet<E>();
}

class _CustomHashSet<E> extends _HashSet<E> {
  final _Equality<E> _equality;
  final _Hasher<E> _hasher;
  final _Predicate _validKey;
  _CustomHashSet(this._equality, this._hasher, bool validKey(Object o))
      : _validKey = (validKey != null) ? validKey : _defaultTypeTest;

  bool remove(Object element) {
    if (!_validKey(element)) return false;
    return super.remove(element);
  }

  bool contains(Object element) {
    if (!_validKey(element)) return false;
    return super.contains(element);
  }

  E lookup(Object element) {
    if (!_validKey(element)) return null;
    return super.lookup(element);
  }

  bool containsAll(Iterable<Object> elements) {
    for (Object element in elements) {
      if (!_validKey(element) || !this.contains(element)) return false;
    }
    return true;
  }

  void removeAll(Iterable<Object> elements) {
    for (Object element in elements) {
      if (_validKey(element)) {
        super._remove(element, _hasher(element));
      }
    }
  }

  bool _equals(e1, e2) => _equality(e1, e2);
  int _hashCode(e) => _hasher(e);

  HashSet<E> _newSet() => new _CustomHashSet<E>(_equality, _hasher, _validKey);
}

class _HashSetEntry {
  final key;
  final int hashCode;
  _HashSetEntry next;
  _HashSetEntry(this.key, this.hashCode, this.next);

  _HashSetEntry remove() {
    _HashSetEntry result = next;
    next = null;
    return result;
  }
}

class _HashSetIterator<E> implements Iterator<E> {
  final _HashSet _set;
  final int _modificationCount;
  int _index = 0;
  _HashSetEntry _next;
  E _current;

  _HashSetIterator(_HashSet hashSet)
      : _set = hashSet, _modificationCount = hashSet._modificationCount;

  bool moveNext() {
    if (_modificationCount != _set._modificationCount) {
      throw new ConcurrentModificationError(_set);
    }
    if (_next != null) {
      _current = _next.key;
      _next = _next.next;
      return true;
    }
    List<_HashSetEntry> buckets = _set._buckets;
    while (_index < buckets.length) {
      _next = buckets[_index];
      _index = _index + 1;
      if (_next != null) {
        _current = _next.key;
        _next = _next.next;
        return true;
      }
    }
    _current = null;
    return false;
  }

  E get current => _current;
}

// Hash table with open addressing that separates the index from keys/values.
abstract class _HashBase {
  // Each occupied entry in _index is a fixed-size integer that encodes a pair:
  //   [ hash pattern for key | index of entry in _data ]
  // The hash pattern is based on hashCode, but is guaranteed to be non-zero.
  // The length of _index is always a power of two, and there is always at
  // least one unoccupied entry.
  List _index;

  // The number of bits used for each component is determined by table size.
  // The length of _index is twice the number of entries in _data, and both
  // are doubled when _data is full. Thus, _index will have a max load factor
  // of 1/2, which enables one more bit to be used for the hash.
  // TODO(koda): Consider growing _data by factor sqrt(2), twice as often.
  static const int _INITIAL_INDEX_BITS = 3;
  static const int _INITIAL_INDEX_SIZE = 1 << (_INITIAL_INDEX_BITS + 1);

  // Unused and deleted entries are marked by 0 and 1, respectively.
  static const int _UNUSED_PAIR = 0;
  static const int _DELETED_PAIR = 1;

  // Cached in-place mask for the hash pattern component. On 32-bit, the top
  // bits are wasted to avoid Mint allocation.
  // TODO(koda): Reclaim the bits by making the compiler treat hash patterns
  // as unsigned words.
  int _hashMask = (1 << (30 - _INITIAL_INDEX_BITS)) - 1;

  static int _hashPattern(int fullHash, int hashMask, int size) {
    final int maskedHash = fullHash & hashMask;
    // TODO(koda): Consider keeping bit length and use left shift.
    return (maskedHash == 0) ? (size >> 1) : maskedHash * (size >> 1);
  }

  // Linear probing.
  static int _firstProbe(int fullHash, int sizeMask) {
    final int i = fullHash & sizeMask;
    // Light, fast shuffle to mitigate bad hashCode (e.g., sequential).
    return ((i << 1) + i) & sizeMask;
  }
  static int _nextProbe(int i, int sizeMask) => (i + 1) & sizeMask;

  // Fixed-length list of keys (set) or key/value at even/odd indices (map).
  List _data;
  // Length of _data that is used (i.e., keys + values for a map).
  int _usedData = 0;
  // Number of deleted keys.
  int _deletedKeys = 0;

  // A self-loop is used to mark a deleted key or value.
  static bool _isDeleted(List data, Object keyOrValue) =>
      identical(keyOrValue, data);
  static void _setDeletedAt(List data, int d) {
    data[d] = data;
  }

  // Concurrent modification detection relies on this checksum monotonically
  // increasing between reallocations of _data.
  int get _checkSum => _usedData + _deletedKeys;
  bool _isModifiedSince(List oldData, int oldCheckSum) =>
      !identical(_data, oldData) || (_checkSum != oldCheckSum);
}

class _OperatorEqualsAndHashCode {
  int _hashCode(e) => e.hashCode;
  bool _equals(e1, e2) => e1 == e2;
}

class _IdenticalAndIdentityHashCode {
  int _hashCode(e) => identityHashCode(e);
  bool _equals(e1, e2) => identical(e1, e2);
}

// Map with iteration in insertion order (hence "Linked"). New keys are simply
// appended to _data.
class _CompactLinkedHashMap<K, V>
    extends MapBase<K, V> with _HashBase, _OperatorEqualsAndHashCode
    implements LinkedHashMap<K, V> {

  _CompactLinkedHashMap() {
    assert(_HashBase._UNUSED_PAIR == 0);
    _index = new List.filled(_HashBase._INITIAL_INDEX_SIZE, 0);
    _data = new List(_HashBase._INITIAL_INDEX_SIZE);
  }

  int get length => (_usedData >> 1) - _deletedKeys;
  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  void _rehash() {
    if ((_deletedKeys << 2) > _usedData) {
      // TODO(koda): Consider shrinking.
      // TODO(koda): Consider in-place compaction and more costly CME check.
      _init(_index.length, _hashMask, _data, _usedData);
    } else {
      // TODO(koda): Support 32->64 bit transition (and adjust _hashMask).
      _init(_index.length << 1, _hashMask >> 1, _data, _usedData);
    }
  }

  void clear() {
    if (isNotEmpty) {
      _init(_index.length, _hashMask);
    }
  }

  // Allocate new _index and _data, and optionally copy existing contents.
  void _init(int size, int hashMask, [List oldData, int oldUsed]) {
    assert(size & (size - 1) == 0);
    assert(_HashBase._UNUSED_PAIR == 0);
    _index = new List.filled(size, 0);
    _hashMask = hashMask;
    _data = new List(size);
    _usedData = 0;
    _deletedKeys = 0;
    if (oldData != null) {
      for (int i = 0; i < oldUsed; i += 2) {
        var key = oldData[i];
        if (!_HashBase._isDeleted(oldData, key)) {
          // TODO(koda): While there are enough hash bits, avoid hashCode calls.
          this[key] = oldData[i + 1];
        }
      }
    }
  }

  void _insert(K key, V value, int hashPattern, int i) {
    if (_usedData == _data.length) {
      _rehash();
      this[key] = value;
    } else {
      assert(1 <= hashPattern && hashPattern <  (1 << 32));
      final int index = _usedData >> 1;
      assert((index & hashPattern) == 0);
      _index[i] = hashPattern | index;
      _data[_usedData++] = key;
      _data[_usedData++] = value;
    }
  }

  // If key is present, returns the index of the value in _data, else returns
  // the negated insertion point in _index.
  int _findValueOrInsertPoint(K key, int fullHash, int hashPattern, int size) {
    final int sizeMask = size - 1;
    final int maxEntries = size >> 1;
    int i = _HashBase._firstProbe(fullHash, sizeMask);
    int firstDeleted = -1;
    int pair = _index[i];
    while (pair != _HashBase._UNUSED_PAIR) {
      if (pair == _HashBase._DELETED_PAIR) {
        if (firstDeleted < 0){
          firstDeleted = i;
        }
      } else {
        final int entry = hashPattern ^ pair;
        if (entry < maxEntries) {
          final int d = entry << 1;
          if (_equals(key, _data[d])) {
            return d + 1;
          }
        }
      }
      i = _HashBase._nextProbe(i, sizeMask);
      pair = _index[i];
    }
    return firstDeleted >= 0 ? -firstDeleted : -i;
  }

  void operator[]=(K key, V value) {
    final int size = _index.length;
    final int sizeMask = size - 1;
    final int fullHash = _hashCode(key);
    final int hashPattern = _HashBase._hashPattern(fullHash, _hashMask, size);
    final int d = _findValueOrInsertPoint(key, fullHash, hashPattern, size);
    if (d > 0) {
      _data[d] = value;
    } else {
      final int i = -d;
      _insert(key, value, hashPattern, i);
    }
  }

  V putIfAbsent(K key, V ifAbsent()) {
    final int size = _index.length;
    final int sizeMask = size - 1;
    final int maxEntries = size >> 1;
    final int fullHash = _hashCode(key);
    final int hashPattern = _HashBase._hashPattern(fullHash, _hashMask, size);
    final int d = _findValueOrInsertPoint(key, fullHash, hashPattern, size);
    if (d > 0) {
      return _data[d];
    }
    // 'ifAbsent' is allowed to modify the map.
    List oldData = _data;
    int oldCheckSum = _checkSum;
    V value = ifAbsent();
    if (_isModifiedSince(oldData, oldCheckSum)) {
      this[key] = value;
    } else {
      final int i = -d;
      _insert(key, value, hashPattern, i);
    }
    return value;
  }

  V remove(Object key) {
    final int size = _index.length;
    final int sizeMask = size - 1;
    final int maxEntries = size >> 1;
    final int fullHash = _hashCode(key);
    final int hashPattern = _HashBase._hashPattern(fullHash, _hashMask, size);
    int i = _HashBase._firstProbe(fullHash, sizeMask);
    int pair = _index[i];
    while (pair != _HashBase._UNUSED_PAIR) {
      if (pair != _HashBase._DELETED_PAIR) {
        final int entry = hashPattern ^ pair;
        if (entry < maxEntries) {
          final int d = entry << 1;
          if (_equals(key, _data[d])) {
            _index[i] = _HashBase._DELETED_PAIR;
            _HashBase._setDeletedAt(_data, d);
            V value = _data[d + 1];
            _HashBase._setDeletedAt(_data, d + 1);
            ++_deletedKeys;
            return value;
          }
        }
      }
      i = _HashBase._nextProbe(i, sizeMask);
      pair = _index[i];
    }
    return null;
  }

  // If key is absent, return _data (which is never a value).
  Object _getValueOrData(Object key) {
    final int size = _index.length;
    final int sizeMask = size - 1;
    final int maxEntries = size >> 1;
    final int fullHash = _hashCode(key);
    final int hashPattern = _HashBase._hashPattern(fullHash, _hashMask, size);
    int i = _HashBase._firstProbe(fullHash, sizeMask);
    int pair = _index[i];
    while (pair != _HashBase._UNUSED_PAIR) {
      if (pair != _HashBase._DELETED_PAIR) {
        final int entry = hashPattern ^ pair;
        if (entry < maxEntries) {
          final int d = entry << 1;
          if (_equals(key, _data[d])) {
            return _data[d + 1];
          }
        }
      }
      i = _HashBase._nextProbe(i, sizeMask);
      pair = _index[i];
    }
    return _data;
  }

  bool containsKey(Object key) => !identical(_data, _getValueOrData(key));

  V operator[](Object key) {
    var v = _getValueOrData(key);
    return identical(_data, v) ? null : v;
  }

  bool containsValue(Object value) {
    for (var v in values) {
      // Spec. says this should always use "==", also for identity maps, etc.
      if (v == value) {
        return true;
      }
    }
    return false;
  }

  void forEach(void f(K key, V value)) {
    var ki = keys.iterator;
    var vi = values.iterator;
    while (ki.moveNext()) {
      vi.moveNext();
      f(ki.current, vi.current);
    }
  }

  Iterable<K> get keys =>
      new _CompactIterable<K>(this, _data, _usedData, -2, 2);
  Iterable<V> get values =>
      new _CompactIterable<V>(this, _data, _usedData, -1, 2);
}

class _CompactLinkedIdentityHashMap<K, V>
    extends _CompactLinkedHashMap<K, V> with _IdenticalAndIdentityHashCode {
}

class _CompactLinkedCustomHashMap<K, V>
    extends _CompactLinkedHashMap<K, V> {
  final _equality;
  final _hasher;
  final _validKey;

  // TODO(koda): Ask gbracha why I cannot have fields _equals/_hashCode.
  int _hashCode(e) => _hasher(e);
  bool _equals(e1, e2) => _equality(e1, e2);

  bool containsKey(Object o) => _validKey(o) ? super.containsKey(o) : false;
  V operator[](Object o) => _validKey(o) ? super[o] : null;
  V remove(Object o) => _validKey(o) ? super.remove(o) : null;

  _CompactLinkedCustomHashMap(this._equality, this._hasher, validKey)
      : _validKey = (validKey != null) ? validKey : _defaultTypeTest;
}

// Iterates through _data[_offset + _step], _data[_offset + 2*_step], ...
// and checks for concurrent modification.
class _CompactIterable<E> extends IterableBase<E> {
  final _table;
  final List _data;
  final int _len;
  final int _offset;
  final int _step;

  _CompactIterable(this._table, this._data, this._len,
                   this._offset, this._step);

  Iterator<E> get iterator =>
      new _CompactIterator<E>(_table, _data, _len, _offset, _step);

  int get length => _table.length;
  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;
}

class _CompactIterator<E> implements Iterator<E> {
  final _table;
  final List _data;
  final int _len;
  int _offset;
  final int _step;
  final int _checkSum;
  E current;

  _CompactIterator(table, this._data, this._len, this._offset, this._step) :
      _table = table, _checkSum = table._checkSum;

  bool moveNext() {
    if (_table._isModifiedSince(_data, _checkSum)) {
      throw new ConcurrentModificationError(_table);
    }
    do {
      _offset += _step;
    } while (_offset < _len && _HashBase._isDeleted(_data, _data[_offset]));
    if (_offset < _len) {
      current = _data[_offset];
      return true;
    } else {
      current = null;
      return false;
    }
  }
}

// Set implementation, analogous to _CompactLinkedHashMap.
class _CompactLinkedHashSet<E>
    extends SetBase<E> with _HashBase, _OperatorEqualsAndHashCode
    implements LinkedHashSet<E> {

  _CompactLinkedHashSet() {
    assert(_HashBase._UNUSED_PAIR == 0);
    _index = new List.filled(_HashBase._INITIAL_INDEX_SIZE, 0);
    _data = new List(_HashBase._INITIAL_INDEX_SIZE >> 1);
  }

  int get length => _usedData - _deletedKeys;

  void _rehash() {
    if ((_deletedKeys << 1) > _usedData) {
      _init(_index.length, _hashMask, _data, _usedData);
    } else {
      _init(_index.length << 1, _hashMask >> 1, _data, _usedData);
    }
  }

  void clear() {
    if (isNotEmpty) {
      _init(_index.length, _hashMask);
    }
  }

  void _init(int size, int hashMask, [List oldData, int oldUsed]) {
    _index = new List.filled(size, 0);
    _hashMask = hashMask;
    _data = new List(size >> 1);
    _usedData = 0;
    _deletedKeys = 0;
    if (oldData != null) {
      for (int i = 0; i < oldUsed; i += 1) {
        var key = oldData[i];
        if (!_HashBase._isDeleted(oldData, key)) {
          add(key);
        }
      }
    }
  }

  bool add(E key) {
    final int size = _index.length;
    final int sizeMask = size - 1;
    final int maxEntries = size >> 1;
    final int fullHash = _hashCode(key);
    final int hashPattern = _HashBase._hashPattern(fullHash, _hashMask, size);
    int i = _HashBase._firstProbe(fullHash, sizeMask);
    int firstDeleted = -1;
    int pair = _index[i];
    while (pair != _HashBase._UNUSED_PAIR) {
      if (pair == _HashBase._DELETED_PAIR) {
        if (firstDeleted < 0){
          firstDeleted = i;
        }
      } else {
        final int d = hashPattern ^ pair;
        if (d < maxEntries && _equals(key, _data[d])) {
          return false;
        }
      }
      i = _HashBase._nextProbe(i, sizeMask);
      pair = _index[i];
    }
    if (_usedData == _data.length) {
      _rehash();
      add(key);
    } else {
      final int insertionPoint = (firstDeleted >= 0) ? firstDeleted : i;
      assert(1 <= hashPattern && hashPattern < (1 << 32));
      assert((hashPattern & _usedData) == 0);
      _index[insertionPoint] = hashPattern | _usedData;
      _data[_usedData++] = key;
    }
    return true;
  }

  // If key is absent, return _data (which is never a value).
  Object _getKeyOrData(Object key) {
    final int size = _index.length;
    final int sizeMask = size - 1;
    final int maxEntries = size >> 1;
    final int fullHash = _hashCode(key);
    final int hashPattern = _HashBase._hashPattern(fullHash, _hashMask, size);
    int i = _HashBase._firstProbe(fullHash, sizeMask);
    int pair = _index[i];
    while (pair != _HashBase._UNUSED_PAIR) {
      if (pair != _HashBase._DELETED_PAIR) {
        final int d = hashPattern ^ pair;
        if (d < maxEntries && _equals(key, _data[d])) {
          return _data[d];  // Note: Must return the existing key.
        }
      }
      i = _HashBase._nextProbe(i, sizeMask);
      pair = _index[i];
    }
    return _data;
  }

  E lookup(Object key) {
    var k = _getKeyOrData(key);
    return identical(_data, k) ? null : k;
  }

  bool contains(Object key) => !identical(_data, _getKeyOrData(key));

  bool remove(Object key) {
    final int size = _index.length;
    final int sizeMask = size - 1;
    final int maxEntries = size >> 1;
    final int fullHash = _hashCode(key);
    final int hashPattern = _HashBase._hashPattern(fullHash, _hashMask, size);
    int i = _HashBase._firstProbe(fullHash, sizeMask);
    int pair = _index[i];
    while (pair != _HashBase._UNUSED_PAIR) {
      if (pair != _HashBase._DELETED_PAIR) {
        final int d = hashPattern ^ pair;
        if (d < maxEntries && _equals(key, _data[d])) {
          _index[i] = _HashBase._DELETED_PAIR;
          _HashBase._setDeletedAt(_data, d);
          ++_deletedKeys;
          return true;
        }
      }
      i = _HashBase._nextProbe(i, sizeMask);
      pair = _index[i];
    }
    return false;
  }

  Iterator<E> get iterator =>
      new _CompactIterator<E>(this, _data, _usedData, -1, 1);

  // Returns a set of the same type, although this
  // is not required by the spec. (For instance, always using an identity set
  // would be technically correct, albeit surprising.)
  Set<E> toSet() => new _CompactLinkedHashSet<E>()..addAll(this);
}

class _CompactLinkedIdentityHashSet<E>
    extends _CompactLinkedHashSet<E> with _IdenticalAndIdentityHashCode {
  Set<E> toSet() => new _CompactLinkedIdentityHashSet<E>()..addAll(this);
}

class _CompactLinkedCustomHashSet<E>
    extends _CompactLinkedHashSet<E> {
  final _equality;
  final _hasher;
  final _validKey;

  int _hashCode(e) => _hasher(e);
  bool _equals(e1, e2) => _equality(e1, e2);

  bool contains(Object o) => _validKey(o) ? super.contains(o) : false;
  E lookup(Object o) => _validKey(o) ? super.lookup(o) : null;
  bool remove(Object o) => _validKey(o) ? super.remove(o) : false;

  _CompactLinkedCustomHashSet(this._equality, this._hasher, validKey)
      : _validKey = (validKey != null) ? validKey : _defaultTypeTest;

  Set<E> toSet() =>
      new _CompactLinkedCustomHashSet<E>(_equality, _hasher, _validKey)
          ..addAll(this);
}
