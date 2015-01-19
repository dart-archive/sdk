// Generated code. Do not edit.

library person.capnp;

import '../lib/internals.dart' as capnp;
import '../lib/internals.dart' show Text, Data;
export '../lib/internals.dart' show Text, Data;

class Person extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 2;

  Text get name => capnp.readText(this, 0);

  int get age => capnp.readUInt16(this, 0);

  List<Person> get children => capnp.readStructList(new _PersonList(), this, 1);
}

class PersonBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 2;
  int get declaredSize => 24;

  String get name => capnp.readText(this, 0).toString();
  void set name(String value) => capnp.writeText(this, 0, value);

  int get age => capnp.readUInt16(this, 0);
  void set age(int value) => capnp.writeUInt16(this, 0, value);

  List<Person> get children => capnp.readStructList(new _PersonList(), this, 1);
  List<PersonBuilder> initChildren(int length) => capnp.writeStructList(new _PersonListBuilder(length), this, 1);
}


// ------------------------- Private list types -------------------------

class _PersonList extends capnp.StructList implements List<Person> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 2;
  Person operator[](int index) => capnp.readStructListElement(new Person(), this, index);
}

class _PersonListBuilder extends capnp.StructListBuilder implements List<PersonBuilder> {
  final int length;
  _PersonListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 2;
  int get declaredElementSize => 24;

  PersonBuilder operator[](int index) => capnp.writeStructListElement(new PersonBuilder(), this, index);
}

