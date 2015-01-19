// Generated code. Do not edit.

library address_book.capnp;

import '../lib/internals.dart' as capnp;
import '../lib/internals.dart' show Text, Data;
export '../lib/internals.dart' show Text, Data;

enum Type {
  mobile,
  home,
  work,
}

class PhoneNumber extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 1;

  Text get number => capnp.readText(this, 0);

  Type get type => Type.values[capnp.readUInt16(this, 0)];
}

class PhoneNumberBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 1;
  int get declaredSize => 16;

  String get number => capnp.readText(this, 0).toString();
  void set number(String value) => capnp.writeText(this, 0, value);

  Type get type => Type.values[capnp.readUInt16(this, 0)];
  void set type(Type value) => capnp.writeUInt16(this, 0, value.index);
}

class AddressBook extends capnp.Struct {
  int get declaredWords => 0;
  int get declaredPointers => 1;

  List<Person> get people => capnp.readStructList(new _PersonList(), this, 0);
}

class AddressBookBuilder extends capnp.StructBuilder {
  int get declaredWords => 0;
  int get declaredPointers => 1;
  int get declaredSize => 8;

  List<Person> get people => capnp.readStructList(new _PersonList(), this, 0);
  List<PersonBuilder> initPeople(int length) => capnp.writeStructList(new _PersonListBuilder(length), this, 0);
}

class Person extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 4;

  int get id => capnp.readUInt32(this, 0);

  Text get name => capnp.readText(this, 0);

  Text get email => capnp.readText(this, 1);

  List<PhoneNumber> get phones => capnp.readStructList(new _PhoneNumberList(), this, 2);

  bool get employmentIsUnemployed => capnp.readUInt16(this, 4) == 0;
  bool get employmentIsEmployer => capnp.readUInt16(this, 4) == 1;
  Text get employmentEmployer => capnp.readText(this, 3);
  bool get employmentIsSchool => capnp.readUInt16(this, 4) == 2;
  Text get employmentSchool => capnp.readText(this, 3);
  bool get employmentIsSelfEmployed => capnp.readUInt16(this, 4) == 3;
}

class PersonBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 4;
  int get declaredSize => 40;

  int get id => capnp.readUInt32(this, 0);
  void set id(int value) => capnp.writeUInt32(this, 0, value);

  String get name => capnp.readText(this, 0).toString();
  void set name(String value) => capnp.writeText(this, 0, value);

  String get email => capnp.readText(this, 1).toString();
  void set email(String value) => capnp.writeText(this, 1, value);

  List<PhoneNumber> get phones => capnp.readStructList(new _PhoneNumberList(), this, 2);
  List<PhoneNumberBuilder> initPhones(int length) => capnp.writeStructList(new _PhoneNumberListBuilder(length), this, 2);

  bool get employmentIsUnemployed => capnp.readUInt16(this, 4) == 0;
  void employmentSetUnemployed() => capnp.writeUInt16(this, 4, 0);
  bool get employmentIsEmployer => capnp.readUInt16(this, 4) == 1;
  void employmentSetEmployer() => capnp.writeUInt16(this, 4, 1);
  String get employmentEmployer => capnp.readText(this, 3).toString();
  void set employmentEmployer(String value) => capnp.writeText(this, 3, value);
  bool get employmentIsSchool => capnp.readUInt16(this, 4) == 2;
  void employmentSetSchool() => capnp.writeUInt16(this, 4, 2);
  String get employmentSchool => capnp.readText(this, 3).toString();
  void set employmentSchool(String value) => capnp.writeText(this, 3, value);
  bool get employmentIsSelfEmployed => capnp.readUInt16(this, 4) == 3;
  void employmentSetSelfEmployed() => capnp.writeUInt16(this, 4, 3);
}


// ------------------------- Private list types -------------------------

class _PersonList extends capnp.StructList implements List<Person> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 4;
  Person operator[](int index) => capnp.readStructListElement(new Person(), this, index);
}

class _PersonListBuilder extends capnp.StructListBuilder implements List<PersonBuilder> {
  final int length;
  _PersonListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 4;
  int get declaredElementSize => 40;

  PersonBuilder operator[](int index) => capnp.writeStructListElement(new PersonBuilder(), this, index);
}

class _PhoneNumberList extends capnp.StructList implements List<PhoneNumber> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  PhoneNumber operator[](int index) => capnp.readStructListElement(new PhoneNumber(), this, index);
}

class _PhoneNumberListBuilder extends capnp.StructListBuilder implements List<PhoneNumberBuilder> {
  final int length;
  _PhoneNumberListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  int get declaredElementSize => 16;

  PhoneNumberBuilder operator[](int index) => capnp.writeStructListElement(new PhoneNumberBuilder(), this, index);
}

