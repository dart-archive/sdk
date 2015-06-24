// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_OBJECT_H_
#define SRC_VM_OBJECT_H_

#include <string.h>

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/random.h"
#include "src/vm/list.h"
#include "src/shared/utils.h"

namespace fletch {

// This is an overview of the object class hierarchy:
//
//   Object
//     Smi
//     Failure
//     HeapObject
//       Boxed
//       Class
//       Double
//       Function
//       Initializer
//       LargeInteger
//       ComplexHeapObject
//         BaseArray
//           Array
//           ByteArray
//           Stack
//           String
//         Instance
//           Coroutine

class Heap;
class Program;
class SnapshotReader;
class SnapshotWriter;
class Space;

// Abstract super class for all objects in Dart.
class Object {
 public:
  // Trivial type check and cast operations to support natives macros.
  bool IsObject() { return true; }
  static Object* cast(Object* object) { return object; }

  // Type testing.
  // - based on tags.
  inline bool IsSmi();
  inline bool IsHeapObject();
  inline bool IsFailure();

  // - based on type field in class.
  inline bool IsClass();
  inline bool IsArray();
  inline bool IsInstance();
  inline bool IsString();
  inline bool IsFunction();
  inline bool IsLargeInteger();
  inline bool IsByteArray();
  inline bool IsDouble();
  inline bool IsBoxed();
  inline bool IsInitializer();
  inline bool IsStack();
  inline bool IsCoroutine();
  inline bool IsPort();
  inline bool IsForeign();

  // - based on marker field in class.
  inline bool IsNull();
  inline bool IsTrue();
  inline bool IsFalse();

  // - based on complex heap object field in class.
  inline bool IsComplexHeapObject();

  // - based on the flags field in class ComplexHeapObject.
  inline bool IsImmutable();

  // Print object on stdout.
  void Print();
  void ShortPrint();

  // Tag information
  static const int kAlignmentBits = 2;
  static const int kAlignment = 1 << kAlignmentBits;
  static const uword kAlignmentMask = (1 << kAlignmentBits) - 1;

 private:
  friend class Array;
  friend class Instance;

  DISALLOW_IMPLICIT_CONSTRUCTORS(Object);
};

// Small integer (immediate).
class Smi: public Object {
 public:
  // Convert an integer into a Smi. Expects IsValid(value);
  inline static Smi* FromWord(word value);

  // Check whether an integer can be represented as a Smi.
  inline static bool IsValid(int64 value);

  // Retrieve the integer value from this Smi.
  inline word value();

  // Casting.
  static inline Smi* cast(Object* object);

  // Constant Smi values.
  static Smi* zero() { return FromWord(0); }
  static Smi* one()  { return FromWord(1); }

  // Printing.
  void SmiPrint();

  // Tag information.
  static const int kTag = 0;
  static const int kTagSize = 1;
  static const uword kTagMask = (1 << kTagSize) - 1;

  // Min and max limits for Smi values.
  static const word kMinValue =
      -(1L << (kBitsPerPointer - (kTagSize + 1)));
  static const word kMaxValue =
      (1L << (kBitsPerPointer - (kTagSize + 1))) - 1;

  // Min and max limits for portable Smi values (32 bit).
  static const word kMinPortableValue = -(1L << (32 - (kTagSize + 1)));
  static const word kMaxPortableValue = (1L << (32 - (kTagSize + 1))) - 1;

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(Smi);
};

// The instance format describes how an instance of a class looks.
// The bit format of the word is as follows:
//   [MSB...11] Contains the non variable size of the instance.
//   [10]       Whether the object is a ComplexHeapObject.
//   [9-7]      The marker of the instance.
//   [6]        Tells whether all pointers are in the non variable part.
//   [5]        Tells whether the object has a variable part.
//   [4-1]      The type of the instance.
//   [LSB]      Smi tag.
class InstanceFormat {
 public:
  enum Type {
    CLASS_TYPE           = 0,
    INSTANCE_TYPE        = 1,
    STRING_TYPE          = 2,
    ARRAY_TYPE           = 3,
    FUNCTION_TYPE        = 4,
    LARGE_INTEGER_TYPE   = 5,
    BYTE_ARRAY_TYPE      = 6,
    DOUBLE_TYPE          = 7,
    BOXED_TYPE           = 8,
    STACK_TYPE           = 9,
    INITIALIZER_TYPE     = 10,
    IMMEDIATE_TYPE       = 15  // No instances.
  };

  enum Marker {
    NULL_MARKER          = 0,
    TRUE_MARKER          = 1,
    FALSE_MARKER         = 2,
    COROUTINE_MARKER     = 3,
    PORT_MARKER          = 4,
    FOREIGN_MARKER       = 5,
    NO_MARKER            = 7  // Else marker.
  };

  // Factory functions.
  inline static const InstanceFormat instance_format(int number_of_fields,
                                                     Marker marker = NO_MARKER);
  inline static const InstanceFormat class_format();
  inline static const InstanceFormat num_format();
  inline static const InstanceFormat smi_format();
  inline static const InstanceFormat string_format();
  inline static const InstanceFormat array_format();
  inline static const InstanceFormat function_format();
  inline static const InstanceFormat heap_integer_format();
  inline static const InstanceFormat byte_array_format();
  inline static const InstanceFormat double_format();
  inline static const InstanceFormat boxed_format();
  inline static const InstanceFormat stack_format();
  inline static const InstanceFormat initializer_format();
  inline static const InstanceFormat null_format();

  InstanceFormat set_fixed_size(int value) {
    ASSERT(Utils::IsAligned(value, kPointerSize));
    int pointers = value / kPointerSize;
    return InstanceFormat(
        Smi::cast(
            reinterpret_cast<Smi*>(FixedSizeField::update(pointers, as_uword()))));
  }

  // Accessors.
  int fixed_size() {
    return FixedSizeField::decode(as_uword()) * kPointerSize;
  }

  Type type() {
    return TypeField::decode(as_uword());
  }

  bool has_variable_part() {
    return HasVariablePartField::decode(as_uword());
  }

  bool only_pointers_in_fixed_part() {
    return OnlyPointersInFixedPartField::decode(as_uword());
  }

  bool is_complex_heap_object() {
    return ComplexHeapObjectField::decode(as_uword());
  }

  Marker marker() {
    return MarkerField::decode(as_uword());
  }

  Smi* as_smi() { return value_; }

  // Leave LSB for Smi tag.
  class TypeField: public BitField<Type, 1, 4> {};
  class HasVariablePartField: public BoolField<5> {};
  class OnlyPointersInFixedPartField: public BoolField<6> {};
  class MarkerField: public BitField<Marker, 7, 3>{};
  class ComplexHeapObjectField: public BoolField<10> {};
  class FixedSizeField: public BitField<int, 11, 31-11> {};

 private:
  // Constructor only used by factory functions.
  inline explicit InstanceFormat(Type type,
                                 int fixed_size,
                                 bool has_variable_part,
                                 bool only_pointers_in_fixed_part,
                                 bool is_complex_heap_object,
                                 Marker marker);

  // Exclusive access to Class contructing from Smi.
  explicit InstanceFormat(Smi* value): value_(value) {}
  friend class Class;
  friend class InterpreterGeneratorX86;
  friend class InterpreterGeneratorARM;

  uword as_uword() const { return reinterpret_cast<word>(value_); }

  Smi* value_;
};

class Class;
class PointerVisitor;
class ContentVisitor;

class HeapObject: public Object {
 public:
  // Tell whether this is located in new space.
  inline bool IsNew();

  // Convert a raw address to a HeapObject by adding a tag.
  inline static HeapObject* FromAddress(uword address);

  // Returns the true address of this object.
  inline uword address() {
    return reinterpret_cast<uword>(this) - kTag;
  }

  // Retrieve the object format from the class.
  inline InstanceFormat format();

  // Tag information.
  static const int kTag = 1;
  static const int kTagSize = 2;
  static const uword kTagMask = (1 << kTagSize) - 1;

  // Casting.
  static inline HeapObject* cast(Object* obj);

  // [class]: field containing its class.
  inline Class* get_class();
  inline void set_class(Class* value);

  // Scavenge support.
  HeapObject* forwarding_address();
  void set_forwarding_address(HeapObject* value);

  // Snapshot support.
  word forwarding_word();
  void set_forwarding_word(word value);

  void IteratePointers(PointerVisitor* visitor);

  // Returns the clone allocated in to space.
  // Uses a forwarding_address to ensure only one clone.
  HeapObject* CloneInToSpace(Space* to);

  // Sizing.
  int FixedSize();
  int Size();

  // Printing.
  void HeapObjectPrint();
  void HeapObjectShortPrint();

  // Sizing.
  static const int kClassOffset = 0;
  static const int kSize = kClassOffset + kPointerSize;

 protected:
  inline void Initialize(int size, Object* init_value);

  int ComputeAlternativeSize(int fixed_size, int variable_size) {
    ASSERT(Utils::IsAligned(fixed_size, kPointerSize));
    int pointers_size = (fixed_size / kPointerSize) * kAlternativePointerSize;
    return Utils::RoundUp(pointers_size + variable_size,
                          kAlternativePointerSize);
  }

  // Raw field accessors.
  inline void at_put(int offset, Object* value);
  inline Object* at(int offset);
  void RawPrint(const char* title);
  // Returns the class field without checks.
  inline Class* raw_class();

  friend class Heap;
  friend class Program;
  friend class SnapshotWriter;

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(HeapObject);
};

class ComplexHeapObject: public HeapObject {
 public:
  // Casting.
  static inline ComplexHeapObject* cast(Object* obj);

  // [immutable]: field indicating immutability of an object.
  inline bool get_immutable();
  // NOTE: This method will also initialize the idendity hash code to 0.
  inline void set_immutable(bool immutable);

  inline Smi* LazyIdentityHashCode(RandomLCG* random);

  // Sizing.
  static const int kFlagsOffset = HeapObject::kSize;
  static const int kSize = kFlagsOffset + kPointerSize;

  // Leave LSB for Smi tag.
  class FlagsImmutabilityField: public BoolField<1> {};
  class FlagsHashCodeField: public BitField<word, 2, 32 - 2> { };

 protected:
  inline void Initialize(int size, Object* init_value);

  inline void InitializeIdentityHashCode(RandomLCG* random);
  inline void SetIdentityHashCode(Smi* smi);
  inline Smi* IdentityHashCode();
  inline uint32 FlagsBits();
  inline void SetFlagsBits(uint32 bits);

  friend class Heap;
  friend class Program;
  friend class SnapshotWriter;

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(ComplexHeapObject);
};

// Heap allocated integer object with a 64-bit value.
class LargeInteger : public HeapObject {
 public:
  // [value]: the 64-bit integer value.
  inline int64 value();
  inline void set_value(int64 value);

  // Casting.
  static inline LargeInteger* cast(Object* object);

  // Snapshotting.
  void LargeIntegerWriteTo(SnapshotWriter* writer, Class* klass);
  void LargeIntegerReadFrom(SnapshotReader* reader);

  // Printing.
  void LargeIntegerPrint();
  void LargeIntegerShortPrint();

  static int AllocationSize() {
    return Utils::RoundUp(kSize + sizeof(int64), kPointerSize);
  }

  int LargeIntegerSize() { return AllocationSize(); }

  int AlternativeSize() {
    return ComputeAlternativeSize(HeapObject::kSize, sizeof(int64));
  }

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(LargeInteger);
};

// Heap allocated double.
class Double : public HeapObject {
 public:
  // [value]: double value.
  inline double value();
  inline void set_value(double value);

  // Casting.
  static inline Double* cast(Object* object);

  // Printing.
  void DoublePrint();
  void DoubleShortPrint();

  // Snapshotting.
  void DoubleWriteTo(SnapshotWriter* writer, Class* klass);
  void DoubleReadFrom(SnapshotReader* reader);

  // Sizing.
  static int AllocationSize() {
    return Utils::RoundUp(kSize + sizeof(double), kPointerSize);
  }

  int DoubleSize() { return AllocationSize(); }

  int AlternativeSize() {
    return ComputeAlternativeSize(HeapObject::kSize, sizeof(double));
  }

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(Double);
};

// Heap allocated object that boxes a value.
class Boxed : public HeapObject {
 public:
  inline Object* value();
  inline void set_value(Object* value);

  // Casting.
  static inline Boxed* cast(Object* object);

  // Printing.
  void BoxedPrint();
  void BoxedShortPrint();

  static int AllocationSize() { return Utils::RoundUp(kSize, kPointerSize); }

  static const int kValueOffset = HeapObject::kSize;
  static const int kSize = kValueOffset + kPointerSize;
 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(Boxed);
};

class Function;

// Heap allocated object containing a static initializer.
class Initializer : public HeapObject {
 public:
  inline Function* function();
  inline void set_function(Function* value);

  // Casting.
  static inline Initializer* cast(Object* object);

  // Printing.
  void InitializerPrint();
  void InitializerShortPrint();

  // Snapshotting.
  void InitializerWriteTo(SnapshotWriter* writer, Class* klass);
  void InitializerReadFrom(SnapshotReader* reader);

  static int AllocationSize() { return Utils::RoundUp(kSize, kPointerSize); }

  int AlternativeSize() {
    return ComputeAlternativeSize(kSize, 0);
  }

  static const int kFunctionOffset = HeapObject::kSize;
  static const int kSize = kFunctionOffset + kPointerSize;

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(Initializer);
};

// Failure (immediate).
class Failure: public Object {
 public:
  // Converts an error object to a failure.
  static Failure* retry_after_gc() { return Create(RETRY_AFTER_GC); }
  static Failure* wrong_argument_type() { return Create(WRONG_ARGUMENT_TYPE); }
  static Failure* index_out_of_bounds() { return Create(INDEX_OUT_OF_BOUNDS); }
  static Failure* illegal_state() { return Create(ILLEGAL_STATE); }
  static Failure* should_preempt() { return Create(SHOULD_PREEMPT); }

  // Casting.
  static inline Failure* cast(Object* object);

  // Tag information.
  static const int kTag = 3;
  static const int kTagSize = 2;
  static const uword kTagMask = (1 << kTagSize) - 1;

 private:
  enum FailureType {
    RETRY_AFTER_GC,
    WRONG_ARGUMENT_TYPE,
    INDEX_OUT_OF_BOUNDS,
    ILLEGAL_STATE,
    SHOULD_PREEMPT
  };

  static Failure* Create(FailureType type) {
    return reinterpret_cast<Failure*>(type << kTagSize | kTag);
  }

  DISALLOW_IMPLICIT_CONSTRUCTORS(Failure);
};

// Abstract base class for arrays. It provides length behavior.
class BaseArray: public ComplexHeapObject {
 public:
  // [length]: length of the array.
  inline int length();
  inline void set_length(int value);

  // Layout descriptor.
  static const int kLengthOffset = ComplexHeapObject::kSize;
  static const int kSize = kLengthOffset + kPointerSize;

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(BaseArray);
};

class Array: public BaseArray {
 public:
  // Setter and getter for elements.
  inline Object* get(int index);
  inline void set(int index, Object* value);

  // Sizing.
  int ArraySize() {
    return AllocationSize(length());
  }

  static int AllocationSize(int length) {
    return kSize + (length * kPointerSize);
  }

  int AlternativeSize() {
    return ComputeAlternativeSize(kSize, length() * kAlternativePointerSize);
  }

  // Casting.
  static inline Array* cast(Object* obj);

  // Printing.
  void ArrayPrint();
  void ArrayShortPrint();

  // Snapshotting.
  void ArrayWriteTo(SnapshotWriter* writer, Class* klass);
  void ArrayReadFrom(SnapshotReader* reader, int length);

 private:
  // Only Heap should initialize objects.
  inline void Initialize(int length, int size, Object* null);
  friend class Heap;
  DISALLOW_IMPLICIT_CONSTRUCTORS(Array);
};

class ByteArray : public BaseArray {
 public:
  // Setter and getter for elements.
  inline uint8 get(int index);
  inline void set(int index, uint8);

  // Access to byte address.
  inline uint8* byte_address_for(int index);

  // Sizing.
  int ByteArraySize() {
    return AllocationSize(length());
  }

  static int AllocationSize(int length) {
    return kSize + Utils::RoundUp(length, kPointerSize);
  }

  int AlternativeSize() {
    return ComputeAlternativeSize(kSize, length());
  }

  // Snapshotting.
  void ByteArrayWriteTo(SnapshotWriter* writer, Class* klass);
  void ByteArrayReadFrom(SnapshotReader* reader, int length);

  // Casting.
  static inline ByteArray* cast(Object* obj);

  // Printing.
  void ByteArrayPrint();
  void ByteArrayShortPrint();

 private:
  // Only Heap should initialize objects.
  inline void Initialize(int length);
  friend class Heap;
  DISALLOW_IMPLICIT_CONSTRUCTORS(ByteArray);
};

class Instance: public ComplexHeapObject {
 public:
  inline static Instance* cast(Object* value);

  // Fields operations.
  inline Object* GetInstanceField(int index);
  inline void SetInstanceField(int index, Object* object);

  // Sizing.
  inline static int AllocationSize(int number_of_fields) {
    ASSERT(number_of_fields >= 0);
    return kSize + (number_of_fields * kPointerSize);
  }

  inline static int NumberOfFieldsFromAllocationSize(int size) {
    return (size - kSize) / kPointerSize;
  }

  inline int AlternativeSize(Class* klass);

  // Schema change support.
  Instance* CloneTransformed(Heap* heap);

  // Snapshotting.
  void InstanceWriteTo(SnapshotWriter* writer, Class* klass);
  void InstanceReadFrom(SnapshotReader* reader, int nof);

  // Printing.
  void InstancePrint();
  void InstanceShortPrint();

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(Instance);
};

class String: public BaseArray {
 public:
  // Access to individual chars.
  inline uint16_t get_code_unit(int offset);
  inline void set_code_unit(int offset, uint16_t value);

  // Byte-level access to the payload.
  inline uint8* byte_address_for(int index);

  inline static String* cast(Object* value);

  // [hash_value]: Raw hash value, might not be computed yet.
  inline word hash_value();
  inline void set_hash_value(word value);

  // Is the content equal to the given string.
  bool Equals(List<const uint16_t> str);
  bool Equals(String* str);

  // Sizing.
  int StringSize() { return AllocationSize(length()); }
  static int AllocationSize(int length) {
    int bytes = length * sizeof(uint16_t);
    return Utils::RoundUp(kSize + bytes, kPointerSize);
  }

  int AlternativeSize() {
    return ComputeAlternativeSize(kSize, length() * sizeof(uint16_t));
  }

  // Hashing.
  word Hash() {
    word value = hash_value();
    if (value != kNoHashValue) return value;
    return SlowHash();
  }

  // Printing.
  void StringPrint();
  void StringShortPrint();

  // Conversion to C string. The result is allocated with malloc and
  // should be freed by the caller.
  char* ToCString();

  // Snapshotting.
  void StringWriteTo(SnapshotWriter* writer, Class* klass);
  void StringReadFrom(SnapshotReader* reader, int length);

  // Layout descriptor.
  static const int kHashValueOffset = BaseArray::kSize;
  static const int kSize = kHashValueOffset + kPointerSize;

 private:
  // Only Heap should initialize objects.
  inline void Initialize(int size, int length, bool clear);
  inline uint16* address_for(int offset);
  friend class Heap;
  friend class Program;
  friend class Process;

  static const word kNoHashValue = 0;

  // For strings in program space, this function may be called by multiple
  // threads at the same time. They will all compute the same result, so
  // they will all write the same value into the [hash_value] field.
  word SlowHash() {
    word value = Utils::StringHash(address_for(0), length()) & Smi::kMaxValue;
    if (value == kNoHashValue) {
      static const int kNoHashValueReplacement = 1;
      ASSERT(kNoHashValueReplacement != kNoHashValue);
      value = kNoHashValueReplacement;
    }
    ASSERT(Smi::IsValid(value));
    set_hash_value(value);
    return value;
  }
  DISALLOW_IMPLICIT_CONSTRUCTORS(String);
};

class Function: public HeapObject {
 public:
  // [bytecode size]: byte size of the bytecodes.
  inline int bytecode_size();
  inline void set_bytecode_size(int value);

  // [literals size]: number of literals in the literals section.
  inline int literals_size();
  inline void set_literals_size(int value);

  // [arity]: the arity of the Function.
  inline uword arity();
  inline void set_arity(uword value);

  inline static Function* cast(Object* value);

  inline uint8* bytecode_address_for(int index);

  inline Object** literal_address_for(int index);
  inline Object* literal_at(int index);
  inline void set_literal_at(int index, Object* value);

  void* ComputeIntrinsic();

  // Sizing.
  int FunctionSize() {
    int variable_size = BytecodeAllocationSize(bytecode_size()) +
                        literals_size() * kPointerSize;
    return AllocationSize(variable_size);
  }

  int AlternativeSize() {
    // Only used when writing snapshots. We only write snapshots
    // in folded form where there are no literals.
    ASSERT(literals_size() == 0);
    return ComputeAlternativeSize(kSize, bytecode_size());
  }

  Function* UnfoldInToSpace(Space* to, int literals_size);
  Function* FoldInToSpace(Space* to);

  static int BytecodeAllocationSize(int bytecode_size_in_bytes) {
    return Utils::RoundUp(bytecode_size_in_bytes, kPointerSize);
  }

  static int AllocationSize(int variable_size) {
    return Utils::RoundUp(kSize + variable_size, kPointerSize);
  }

  static Function* FromBytecodePointer(uint8* bcp,
                                       int* frame_ranges_offset = NULL);

  static inline Object* ConstantForBytecode(uint8* bcp);

  // Snapshotting.
  void FunctionWriteTo(SnapshotWriter* writer, Class* klass);
  void FunctionReadFrom(SnapshotReader* reader, int length);

  // Printing.
  void FunctionPrint();
  void FunctionShortPrint();

  // Layout descriptor.
  static const int kBytecodeSizeOffset = HeapObject::kSize;
  static const int kLiteralsSizeOffset = kBytecodeSizeOffset + kPointerSize;
  static const int kArityOffset = kLiteralsSizeOffset + kPointerSize;
  static const int kSize = kArityOffset + kPointerSize;

 private:
  void Initialize(List<uint8> bytecodes);
  friend class Heap;
  inline void set_byte(int offset, uint8 value);
  DISALLOW_IMPLICIT_CONSTRUCTORS(Function);
};

class Class: public HeapObject {
 public:
  // [super]: field containing the super class.
  inline bool has_super_class();
  inline Class* super_class();
  inline void set_super_class(Class* value);

  // [instance_format]: describes instance format.
  inline InstanceFormat instance_format();
  inline void set_instance_format(InstanceFormat value);

  // [id] or [link]: class id or link to next class while folding.
  inline int id();
  inline void set_id(int value);
  inline Object* link();
  inline void set_link(Object* value);

  // [child_id] or [child_link]: class id of last child or link to
  // children while folding.
  inline int child_id();
  inline void set_child_id(int value);
  inline Object* child_link();
  inline void set_child_link(Object* value);

  // [methods]: array containing pairs of (Smi*, Function*) sorted by Smi*
  // values.
  inline bool has_methods();
  inline Array* methods();
  inline void set_methods(Array* value);

  // Compute the number of instance fields from the instance format
  // description. Can only be used on instance classes.
  inline int NumberOfInstanceFields();

  // Schema change support.
  inline bool IsTransformed();
  void Transform(Class* target, Array* transformation);

  inline Class* TransformationTarget();
  inline Array* Transformation();

  inline static Class* cast(Object* value);

  static int AllocationSize() { return Utils::RoundUp(kSize, kPointerSize); }

  int AlternativeSize() {
    return ComputeAlternativeSize(kSize, 0);
  }

  // Is this class a subclass of the given class?
  bool IsSubclassOf(Class* klass);

  // Field operations.
  inline Object* GetStaticField(int index);
  inline void SetStaticField(int index, Object* object);

  // Snapshotting.
  void ClassWriteTo(SnapshotWriter* writer, Class* klass);
  void ClassReadFrom(SnapshotReader* reader);

  // Printing.
  void ClassPrint();
  void ClassShortPrint();

  // Lookup a method for the given selector in the super class chain
  // of this class. Returns NULL if no matching method could be found.
  Function* LookupMethod(int selector);

  // Layout descriptor.
  static const int kSuperClassOffset =
      HeapObject::kSize;
  static const int kInstanceFormatOffset =
      kSuperClassOffset + kPointerSize;
  static const int kIdOrTransformationTargetOffset =
      kInstanceFormatOffset + kPointerSize;
  static const int kChildIdOrTransformationOffset =
      kIdOrTransformationTargetOffset + kPointerSize;
  static const int kMethodsOffset =
      kChildIdOrTransformationOffset + kPointerSize;
  static const int kSize =
      kMethodsOffset + kPointerSize;

 private:
  friend class Heap;
  inline void Initialize(InstanceFormat format, int size, Object* null);
  DISALLOW_IMPLICIT_CONSTRUCTORS(Class);
};

// A stack-object that has 0..limit objects alive.
class Stack: public BaseArray {
 public:
  // [top]: top of the stack.
  inline int top();
  inline void set_top(int value);

  // [next]: stacks are chained in a list through a next pointer
  // during program garbage collection.
  inline Object* next();
  inline void set_next(Object* next);

  // Setter and getter for elements.
  inline Object* get(int index);
  inline void set(int index, Object* value);

  inline Object** Pointer(int index);
  inline void SetTopFromPointer(Object** value);

  // Sizing.
  int StackSize() {
    return AllocationSize(length());
  }
  static int AllocationSize(int length) {
    return kSize + (length * kPointerSize);
  }

  // Casting.
  static inline Stack* cast(Object* obj);

  // Printing.
  void StackPrint();
  void StackShortPrint();

  // Snapshotting.
  void StackWriteTo(SnapshotWriter* writer, Class* klass);
  void StackReadFrom(SnapshotReader* reader, int length);

  // Layout descriptor.
  static const int kTopOffset = BaseArray::kSize;
  static const int kNextOffset = kTopOffset + kPointerSize;
  static const int kSize = kNextOffset + kPointerSize;

 private:
  // Only Heap should initialize objects.
  inline void Initialize(int length);
  friend class Heap;
  DISALLOW_IMPLICIT_CONSTRUCTORS(Stack);
};

class Coroutine: public Instance {
 public:
  // [stack]: field containing the stack.
  inline bool has_stack();
  inline Stack* stack();
  inline Object** stack_address();
  inline void set_stack(Object* value);

  // [caller]: field containing the caller.
  inline bool has_caller();
  inline Coroutine* caller();
  inline void set_caller(Coroutine* value);

  // Casting.
  static inline Coroutine* cast(Object* obj);

  // Layout descriptor.
  static const int kStackOffset = Instance::kSize;
  static const int kCallerOffset = kStackOffset + kPointerSize;
  static const int kSize = kCallerOffset + kPointerSize;

 private:
  DISALLOW_IMPLICIT_CONSTRUCTORS(Coroutine);
};

// Abstract base class for visiting, and optionally modifying, the
// pointers contained in Objects. Used in GC and serialization/deserialization.
class PointerVisitor {
 public:
  virtual ~PointerVisitor() { }

  // Visits a contiguous arrays of pointers in the half-open range
  // [start, end). Any or all of the values may be modified on return.
  virtual void VisitBlock(Object** start, Object** end) = 0;

  // Handy shorthand for visiting a single pointer.
  virtual void Visit(Object** p) { VisitBlock(p, p + 1); }

  // Handy shorthand for visiting a class field in an object.
  virtual void VisitClass(Object** p) { VisitBlock(p, p + 1); }
};

// Abstract base class for visiting all objects in a space.
class HeapObjectVisitor {
 public:
  virtual ~HeapObjectVisitor() {}
  virtual void Visit(HeapObject* object) = 0;
};

// Inlined InstanceFormat functions.

InstanceFormat::InstanceFormat(Type type,
                               int fixed_size,
                               bool has_variable_part,
                               bool only_pointers_in_fixed_part,
                               bool is_complex_heap_object,
                               Marker marker = NO_MARKER) {
  ASSERT(Utils::IsAligned(fixed_size, kPointerSize));
  uword v = TypeField::encode(type)
      | HasVariablePartField::encode(has_variable_part)
      | OnlyPointersInFixedPartField::encode(only_pointers_in_fixed_part)
      | MarkerField::encode(marker)
      | ComplexHeapObjectField::encode(is_complex_heap_object)
      | FixedSizeField::encode(fixed_size / kPointerSize);
  value_ = Smi::cast(reinterpret_cast<Smi*>(v));
  ASSERT(type == this->type());
  ASSERT(fixed_size == this->fixed_size());
  ASSERT(only_pointers_in_fixed_part == this->only_pointers_in_fixed_part());
  ASSERT(has_variable_part == this->has_variable_part());
}

const InstanceFormat InstanceFormat::heap_integer_format() {
  return InstanceFormat(
      LARGE_INTEGER_TYPE, LargeInteger::kSize, true, true, false);
}

const InstanceFormat InstanceFormat::byte_array_format() {
  return InstanceFormat(BYTE_ARRAY_TYPE, ByteArray::kSize, true, true, true);
}

const InstanceFormat InstanceFormat::double_format() {
  return InstanceFormat(DOUBLE_TYPE, Double::kSize, true, true, false);
}

const InstanceFormat InstanceFormat::boxed_format() {
  return InstanceFormat(BOXED_TYPE, Boxed::kSize, false, true, false);
}

const InstanceFormat InstanceFormat::initializer_format() {
  return InstanceFormat(
      INITIALIZER_TYPE, Initializer::kSize, false, true, false);
}

const InstanceFormat InstanceFormat::function_format() {
  return InstanceFormat(FUNCTION_TYPE, Function::kSize, true, false, false);
}

const InstanceFormat InstanceFormat::instance_format(int number_of_fields,
                                                     Marker marker) {
  return InstanceFormat(INSTANCE_TYPE,
                        Instance::AllocationSize(number_of_fields),
                        false,
                        true,
                        true,
                        marker);
}

const InstanceFormat InstanceFormat::class_format() {
  return InstanceFormat(
      CLASS_TYPE, Class::AllocationSize(), false, true, false);
}

const InstanceFormat InstanceFormat::smi_format() {
  return InstanceFormat(IMMEDIATE_TYPE, 0, false, false, false);
}

const InstanceFormat InstanceFormat::num_format() {
  // TODO(ager): This is not really an immediate type. It is an
  // abstract class and therefore doesn't have any instances.
  return InstanceFormat(IMMEDIATE_TYPE, 0, false, false, false);
}

const InstanceFormat InstanceFormat::string_format() {
  return InstanceFormat(STRING_TYPE, String::kSize, true, true, true);
}

const InstanceFormat InstanceFormat::array_format() {
  return InstanceFormat(ARRAY_TYPE, Array::kSize, true, false, true);
}

const InstanceFormat InstanceFormat::stack_format() {
  return InstanceFormat(STACK_TYPE, Stack::kSize, true, false, true);
}

// Inlined Object functions.

bool Object::IsSmi() {
  int tag = reinterpret_cast<uword>(this) & Smi::kTagMask;
  return tag == Smi::kTag;
}

bool Object::IsHeapObject() {
  int tag = reinterpret_cast<uword>(this) & HeapObject::kTagMask;
  return tag == HeapObject::kTag;
}

bool Object::IsComplexHeapObject() {
  if (IsSmi()) return false;
  return HeapObject::cast(this)->format().is_complex_heap_object();
}

bool Object::IsFailure() {
  int tag = reinterpret_cast<uword>(this) & Failure::kTagMask;
  return tag == Failure::kTag;
}

bool Object::IsClass() {
  if (IsHeapObject()) {
    HeapObject* h = HeapObject::cast(this);
    return h->format().type() == InstanceFormat::CLASS_TYPE;
  }
  return false;
}

bool Object::IsString() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::STRING_TYPE;
}

bool Object::IsArray() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::ARRAY_TYPE;
}

bool Object::IsInstance() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::INSTANCE_TYPE;
}

bool Object::IsFunction() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::FUNCTION_TYPE;
}

bool Object::IsLargeInteger() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::LARGE_INTEGER_TYPE;
}

bool Object::IsByteArray() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::BYTE_ARRAY_TYPE;
}

bool Object::IsDouble() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::DOUBLE_TYPE;
}

bool Object::IsBoxed() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::BOXED_TYPE;
}

bool Object::IsInitializer() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::INITIALIZER_TYPE;
}

bool Object::IsStack() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().type() == InstanceFormat::STACK_TYPE;
}

bool Object::IsCoroutine() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().marker() == InstanceFormat::COROUTINE_MARKER;
}

bool Object::IsPort() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().marker() == InstanceFormat::PORT_MARKER;
}

bool Object::IsForeign() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().marker() == InstanceFormat::FOREIGN_MARKER;
}

bool Object::IsNull() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().marker() == InstanceFormat::NULL_MARKER;
}

bool Object::IsTrue() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().marker() == InstanceFormat::TRUE_MARKER;
}

bool Object::IsFalse() {
  if (IsSmi()) return false;
  HeapObject* h = HeapObject::cast(this);
  return h->format().marker() == InstanceFormat::FALSE_MARKER;
}

bool Object::IsImmutable() {
  if (IsSmi()) return true;

  ASSERT(IsHeapObject());
  if (IsBoxed()) return false;
  if (IsComplexHeapObject()) {
    return ComplexHeapObject::cast(this)->get_immutable();
  }
  return true;
}

// Inlined Smi functions.

Smi* Smi::cast(Object* object) {
  ASSERT(object->IsSmi());
  return reinterpret_cast<Smi*>(object);
}

word Smi::value() {
  return reinterpret_cast<word>(this) >> kTagSize;
}

Smi* Smi::FromWord(word value) {
  ASSERT(Smi::IsValid(value));
  return reinterpret_cast<Smi*>((value << kTagSize) | kTag);
}

bool Smi::IsValid(int64 value) {
  return (value >= kMinValue) && (value <= kMaxValue);
}

// Inlined HeapObject functions.
HeapObject* HeapObject::cast(Object* object) {
  ASSERT(object->IsHeapObject());
  return reinterpret_cast<HeapObject*>(object);
}

HeapObject* HeapObject::FromAddress(uword raw_address) {
  ASSERT((raw_address & kTagMask) == 0);
  return reinterpret_cast<HeapObject*>(raw_address + kTag);
}

InstanceFormat HeapObject::format() {
  return raw_class()->instance_format();
}

bool HeapObject::IsNew() {
  // A heap object is in new space iff the first bit after the tag bits is 1.
  return (reinterpret_cast<uword>(this) & (kTagMask + 1)) != 0;
}

void HeapObject::at_put(int offset, Object* value) {
  *reinterpret_cast<Object**>(address() + offset) = value;
}

Object* HeapObject::at(int offset) {
  return *reinterpret_cast<Object**>(address() + offset);
}

Class* HeapObject::get_class() {
  return Class::cast(at(kClassOffset));
}

Class* HeapObject::raw_class() {
  return reinterpret_cast<Class*>(at(kClassOffset));
}

void HeapObject::set_class(Class* value) {
  at_put(kClassOffset, value);
}

ComplexHeapObject* ComplexHeapObject::cast(Object* object) {
  ASSERT(object->IsComplexHeapObject());
  return reinterpret_cast<ComplexHeapObject*>(object);
}

bool ComplexHeapObject::get_immutable() {
  return FlagsImmutabilityField::decode(
      reinterpret_cast<word>(Smi::cast(at(kFlagsOffset))));
}

void ComplexHeapObject::set_immutable(bool immutable) {
  word flags = FlagsImmutabilityField::encode(immutable);
  at_put(kFlagsOffset, reinterpret_cast<Smi*>(flags));
}

Smi* ComplexHeapObject::LazyIdentityHashCode(RandomLCG* random) {
  Smi* hash_code = IdentityHashCode();
  if (hash_code->value() == 0) {
    InitializeIdentityHashCode(random);
    hash_code = IdentityHashCode();
  }
  return hash_code;
}

void ComplexHeapObject::Initialize(int size, Object* null) {
  // Initialize the body of the instance.
  for (int offset = kSize; offset < size; offset += kPointerSize) {
    at_put(offset, null);
  }
}

void ComplexHeapObject::InitializeIdentityHashCode(RandomLCG* random) {
  // Taking the most significant FlagsHashCodeField size bits of a
  // random number might be 0. So we keep getting random numbers until
  // we've received a non-0 value.
  while (true) {
    word hash_code = FlagsHashCodeField::decode(random->NextUInt32());
    if (hash_code != 0) {
      SetIdentityHashCode(Smi::FromWord(hash_code));
      return;
    }
  }
}

void ComplexHeapObject::SetIdentityHashCode(Smi* smi) {
  word hash_code = smi->value();
  word flags = reinterpret_cast<word>(at(kFlagsOffset));
  flags = FlagsHashCodeField::update(hash_code, flags);
  at_put(kFlagsOffset, reinterpret_cast<Smi*>(flags));

  // Make sure that encoding the hashcode doesn't truncate any bits.
  ASSERT(FlagsHashCodeField::decode(flags) == hash_code);
}

Smi* ComplexHeapObject::IdentityHashCode() {
  word flags = reinterpret_cast<word>(at(kFlagsOffset));
  return Smi::FromWord(FlagsHashCodeField::decode(flags));
}

uint32 ComplexHeapObject::FlagsBits() {
  // Convert to unsigned word sized integer before expanding to 64
  // bits. This is important on 32-bit systems where the conversion to
  // integral types otherwise performs a sign extension first.
  uint64 bits = reinterpret_cast<uword>(at(kFlagsOffset));
  ASSERT((bits >> 32) == 0);
  return static_cast<uint32>(bits);
}

void ComplexHeapObject::SetFlagsBits(uint32 bits) {
  Smi* value = reinterpret_cast<Smi*>(bits);
  ASSERT(value->IsSmi());
  at_put(kFlagsOffset, value);
}

void HeapObject::Initialize(int size, Object* null) {
  // Initialize the body of the instance.
  for (int offset = HeapObject::kSize;
       offset < size;
       offset += kPointerSize) {
    at_put(offset, null);
  }
}

// Inlined Failure functions.

Failure* Failure::cast(Object* object) {
  ASSERT(object->IsFailure());
  return reinterpret_cast<Failure*>(object);
}

// Inlined BaseArray functions.

int BaseArray::length() {
  return Smi::cast(at(kLengthOffset))->value();
}

void BaseArray::set_length(int value) {
  at_put(kLengthOffset, Smi::FromWord(value));
}

// Inlined Array functions.

Array* Array::cast(Object* object) {
  ASSERT(object->IsArray());
  return reinterpret_cast<Array*>(object);
}

Object* Array::get(int index) {
  ASSERT(index >= 0 && index < length());
  return at(Array::kSize + (index * kPointerSize));
}

void Array::set(int index, Object* value) {
  ASSERT(index >= 0 && index < length());
  at_put(Array::kSize + (index * kPointerSize), value);
}

void Array::Initialize(int length, int size, Object* null) {
  set_length(length);
  // Initialize the body of the instance.
  for (int offset = BaseArray::kSize;
       offset < size;
       offset += kPointerSize) {
    at_put(offset, null);
  }
}

// Inlined ByteArray functions.

ByteArray* ByteArray::cast(Object* object) {
  ASSERT(object->IsByteArray());
  return reinterpret_cast<ByteArray*>(object);
}

uint8* ByteArray::byte_address_for(int index) {
  ASSERT(index >= 0 && index < length());
  return reinterpret_cast<uint8*>(address() + kSize + index);
}

uint8 ByteArray::get(int index) {
  ASSERT(index >= 0 && index < length());
  return *reinterpret_cast<uint8*>(address() + kSize + index);
}

void ByteArray::set(int index, uint8 value) {
  ASSERT(index >= 0 && index < length());
  ASSERT(Utils::IsUint8(value));
  *reinterpret_cast<uint8*>(address() + kSize + index) = value;
}

void ByteArray::Initialize(int length) {
  set_length(length);
  memset(reinterpret_cast<void*>(address() + kSize), 0, length - kSize);
}

// Inlined Class functions.

bool Class::has_super_class() {
  return at(kSuperClassOffset)->IsClass();
}

Class* Class::super_class() {
  return Class::cast(at(kSuperClassOffset));
}

void Class::set_super_class(Class* value) {
  ASSERT(this != value);  // Don't create cycles.
  at_put(kSuperClassOffset, value);
}

InstanceFormat Class::instance_format() {
  return InstanceFormat(Smi::cast(at(kInstanceFormatOffset)));
}

void Class::set_instance_format(InstanceFormat value) {
  at_put(kInstanceFormatOffset, value.as_smi());
}

int Class::id() {
  return Smi::cast(at(kIdOrTransformationTargetOffset))->value();
}

void Class::set_id(int value) {
  at_put(kIdOrTransformationTargetOffset, Smi::FromWord(value));
}

Object* Class::link() {
  return at(kIdOrTransformationTargetOffset);
}

void Class::set_link(Object* value) {
  at_put(kIdOrTransformationTargetOffset, value);
}

int Class::child_id() {
  return Smi::cast(at(kChildIdOrTransformationOffset))->value();
}

void Class::set_child_id(int value) {
  at_put(kChildIdOrTransformationOffset, Smi::FromWord(value));
}

Object* Class::child_link() {
  return at(kChildIdOrTransformationOffset);
}

void Class::set_child_link(Object* value) {
  at_put(kChildIdOrTransformationOffset, value);
}

void Class::Initialize(InstanceFormat format, int size, Object* null) {
  for (int offset = HeapObject::kSize;
       offset < size;
       offset += kPointerSize) {
    at_put(offset, null);
  }
  set_instance_format(format);
}

bool Class::has_methods() {
  return at(kMethodsOffset)->IsArray();
}

Array* Class::methods() {
  return Array::cast(at(kMethodsOffset));
}

void Class::set_methods(Array* value) {
  at_put(kMethodsOffset, value);
}

bool Class::IsTransformed() {
  return at(kIdOrTransformationTargetOffset)->IsClass();
}

Class* Class::TransformationTarget() {
  ASSERT(IsTransformed());
  return Class::cast(at(kIdOrTransformationTargetOffset));
}

Array* Class::Transformation() {
  ASSERT(IsTransformed());
  return Array::cast(at(kChildIdOrTransformationOffset));
}

int Class::NumberOfInstanceFields() {
  InstanceFormat format = instance_format();
  ASSERT(format.type() == InstanceFormat::INSTANCE_TYPE);
  return Instance::NumberOfFieldsFromAllocationSize(format.fixed_size());
}

Class* Class::cast(Object* object) {
  ASSERT(object->IsClass());
  return reinterpret_cast<Class*>(object);
}

Object* Class::GetStaticField(int index) {
  return at(kSize + (index * kPointerSize));
}

void Class::SetStaticField(int index, Object* object) {
  at_put(kSize + (index * kPointerSize), object);
}

// Inlined String functions.

String* String::cast(Object* object) {
  ASSERT(object->IsString());
  return reinterpret_cast<String*>(object);
}

uint16_t String::get_code_unit(int offset) {
  offset *= sizeof(uint16_t);
  return *reinterpret_cast<uint16_t*>(address() + kSize + offset);
}

void String::set_code_unit(int offset, uint16_t value) {
  offset *= sizeof(uint16_t);
  *reinterpret_cast<uint16_t*>(address() + kSize + offset) = value;
}

uint8_t* String::byte_address_for(int offset) {
  offset *= sizeof(uint16_t);
  return reinterpret_cast<uint8_t*>(address() + kSize + offset);
}

uint16_t* String::address_for(int offset) {
  offset *= sizeof(uint16_t);
  return reinterpret_cast<uint16_t*>(address() + kSize + offset);
}

void String::Initialize(int size, int length, bool clear) {
  set_length(length);
  set_hash_value(kNoHashValue);
  // Clear the body.
  if (clear) {
    memset(reinterpret_cast<void*>(address() + kSize), 0, size - kSize);
  }
}

word String::hash_value() {
  return *reinterpret_cast<word*>(address() + kHashValueOffset);
}

void String::set_hash_value(word value) {
  *reinterpret_cast<word*>(address() + kHashValueOffset) = value;
}

// Inlined Instance functions.

Instance* Instance::cast(Object* object) {
  ASSERT(object->IsInstance());
  return reinterpret_cast<Instance*>(object);
}

Object* Instance::GetInstanceField(int index) {
  return at(ComplexHeapObject::kSize + (index * kPointerSize));
}

void Instance::SetInstanceField(int index, Object* object) {
  at_put(ComplexHeapObject::kSize + (index * kPointerSize), object);
}

int Instance::AlternativeSize(Class* klass) {
  int fields = klass->NumberOfInstanceFields();
  return ComputeAlternativeSize(kSize, fields * kAlternativePointerSize);
}

// Inlined Function functions.

uword Function::arity() {
  return Smi::cast(at(kArityOffset))->value();
}

void Function::set_arity(uword value) {
  at_put(kArityOffset, Smi::FromWord(value));
}

void Function::set_literals_size(int value) {
  at_put(kLiteralsSizeOffset, Smi::FromWord(value));
}

int Function::literals_size() {
  return Smi::cast(at(kLiteralsSizeOffset))->value();
}

Object** Function::literal_address_for(int index) {
  int rounded_bytecode_size = BytecodeAllocationSize(bytecode_size());
  int offset = kSize + rounded_bytecode_size + index * kPointerSize;
  return reinterpret_cast<Object**>(address() + offset);
}

Object* Function::literal_at(int index) {
  ASSERT(index >= 0 && index < literals_size());
  int rounded_bytecode_size = BytecodeAllocationSize(bytecode_size());
  int offset = kSize + rounded_bytecode_size + index * kPointerSize;
  return at(offset);
}

void Function::set_literal_at(int index, Object* value) {
  ASSERT(index >= 0 && index < literals_size());
  int rounded_bytecode_size = BytecodeAllocationSize(bytecode_size());
  int offset = kSize + rounded_bytecode_size + index * kPointerSize;
  at_put(offset, value);
}

int Function::bytecode_size() {
  return Smi::cast(at(kBytecodeSizeOffset))->value();
}

void Function::set_bytecode_size(int value) {
  at_put(kBytecodeSizeOffset, Smi::FromWord(value));
}

uint8* Function::bytecode_address_for(int index) {
  ASSERT(index >= 0 && index < bytecode_size());
  return reinterpret_cast<uint8*>(address() + kSize + index);
}

Function* Function::cast(Object* object) {
  ASSERT(object->IsFunction());
  return reinterpret_cast<Function*>(object);
}

void Function::set_byte(int offset, uint8 value) {
  *reinterpret_cast<uint8*>(address() + Function::kSize + offset) = value;
}

Object* Function::ConstantForBytecode(uint8* bcp) {
  int offset = Utils::ReadInt32(bcp + 1);
  uint8* address = bcp + offset;
  return *reinterpret_cast<Object**>(address);
}

// Inlined LargeInteger functions.

int64 LargeInteger::value() {
  return *reinterpret_cast<int64*>(address() + HeapObject::kSize);
}

void LargeInteger::set_value(int64 value) {
  *reinterpret_cast<int64*>(address() + HeapObject::kSize) = value;
}

LargeInteger* LargeInteger::cast(Object* object) {
  ASSERT(object->IsLargeInteger());
  return reinterpret_cast<LargeInteger*>(object);
}

// Inlined Double functions.

double Double::value() {
  return *reinterpret_cast<double*>(address() + HeapObject::kSize);
}

void Double::set_value(double value) {
  *reinterpret_cast<double*>(address() + HeapObject::kSize) = value;
}

Double* Double::cast(Object* object) {
  ASSERT(object->IsDouble());
  return reinterpret_cast<Double*>(object);
}

// Inlined Boxed functions.

Object* Boxed::value() {
  return at(kValueOffset);
}

void Boxed::set_value(Object* value) {
  return at_put(kValueOffset, value);
}

Boxed* Boxed::cast(Object* object) {
  ASSERT(object->IsBoxed());
  return reinterpret_cast<Boxed*>(object);
}

// Inlined Initializer functions.

Function* Initializer::function() {
  return Function::cast(at(kFunctionOffset));
}

void Initializer::set_function(Function* value) {
  at_put(kFunctionOffset, value);
}

Initializer* Initializer::cast(Object* object) {
  ASSERT(object->IsInitializer());
  return reinterpret_cast<Initializer*>(object);
}

// Inlined Stack functions.

Stack* Stack::cast(Object* object) {
  ASSERT(object->IsStack());
  return reinterpret_cast<Stack*>(object);
}

Object* Stack::get(int index) {
  ASSERT(index >= 0 && index < length());
  return at(Stack::kSize + (index * kPointerSize));
}

void Stack::set(int index, Object* value) {
  ASSERT(index >= 0 && index < length());
  at_put(Stack::kSize + (index * kPointerSize), value);
}

int Stack::top() {
  return Smi::cast(at(Stack::kTopOffset))->value();
}

void Stack::set_top(int value) {
  ASSERT(value >= 0 && value < length());
  at_put(Stack::kTopOffset, Smi::FromWord(value));
}

Object* Stack::next() {
  return at(Stack::kNextOffset);
}

void Stack::set_next(Object* value) {
  at_put(Stack::kNextOffset, value);
}

inline Object** Stack::Pointer(int index) {
  return reinterpret_cast<Object**>(
      address() + Stack::kSize + (index * kPointerSize));
}

inline void Stack::SetTopFromPointer(Object** value) {
  Object** start = reinterpret_cast<Object**>(address() + Stack::kSize);
  int new_top = value - start;
  set_top(new_top);
}

inline void Stack::Initialize(int length) {
  set_length(length);
  set_top(0);
  set_next(Smi::FromWord(0));
}

// Inlined Coroutine functions.

inline Coroutine* Coroutine::cast(Object* object) {
  ASSERT(object->IsCoroutine());
  return reinterpret_cast<Coroutine*>(object);
}

inline bool Coroutine::has_stack() {
  return !at(kStackOffset)->IsNull();
}

inline Stack* Coroutine::stack() {
  return Stack::cast(at(kStackOffset));
}

inline Object** Coroutine::stack_address() {
  return reinterpret_cast<Object**>(address() + kStackOffset);
}

inline void Coroutine::set_stack(Object* value) {
  ASSERT(value->IsNull() || value->IsStack());
  at_put(kStackOffset, value);
}

inline bool Coroutine::has_caller() {
  return !at(kCallerOffset)->IsNull();
}

inline Coroutine* Coroutine::caller() {
  return Coroutine::cast(at(kCallerOffset));
}

inline void Coroutine::set_caller(Coroutine* value) {
  at_put(kCallerOffset, value);
}

}  // namespace fletch


#endif  // SRC_VM_OBJECT_H_
