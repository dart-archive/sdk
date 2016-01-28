// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:typed_data' show ByteData;

import 'address_book.capnp.dart';
import '../lib/message.dart';
import '../lib/serialize.dart';

// TODO(kasperl): Avoid clashing with names in dart:core.
import 'dart:core' hide Type;

void main() {
  printAddressBook(writeAddressBook());
}

ByteData writeAddressBook() {
  MessageBuilder message = new BufferedMessageBuilder();
  AddressBookBuilder addressBook = message.initRoot(new AddressBookBuilder());

  List<PersonBuilder> people = addressBook.initPeople(2);
  PersonBuilder alice = people[0];
  alice.id = 123;
  alice.name = "Alice";
  alice.email = "alice@example.com";
  List<PhoneNumberBuilder> alicePhones = alice.initPhones(1);
  alicePhones[0].number = "555-1212";
  alicePhones[0].type = Type.home;

  // TODO(kasperl): The C++ version automatically sets the employment
  // kind when writing to the employment.school field. Should we also
  // do that? Seems pretty convenient.
  alice.employmentSetSchool();
  alice.employmentSchool = "MIT";

  PersonBuilder bob = people[1];
  bob.id = 456;
  bob.name = "Bob";
  bob.email = "bob@example.com";
  List<PhoneNumberBuilder> bobPhones = bob.initPhones(2);
  bobPhones[0].number = "555-4567";
  bobPhones[0].type = Type.home;
  bobPhones[1].number = "555-7654";
  bobPhones[1].type = Type.work;
  bob.employmentSetUnemployed();

  return message.toFlatList();
}

void printAddressBook(ByteData bytes) {
  MessageReader message = new BufferedMessageReader(bytes);
  AddressBook addressBook = message.getRoot(new AddressBook());

  for (Person person in addressBook.people) {
    print('${person.name}: ${person.email}');
    for (PhoneNumber phone in person.phones) {
      Map<Type, String> typeNameMap = const {
        Type.mobile : 'mobile',
        Type.home   : 'home',
        Type.work   : 'work',
      };
      String typeName = typeNameMap[phone.type];
      print('  $typeName phone: ${phone.number}');
    }

    // TODO(kasperl): The C++ version has a 'which' enum for the possible
    // union values so you can switch over the possibilities. Maybe it would
    // make sense to add that too?
    if (person.employmentIsUnemployed) {
      print('  unemployed');
    } else if (person.employmentIsEmployer) {
      print('  employer: ${person.employmentEmployer}');
    } else if (person.employmentIsSchool) {
      print('  student at: ${person.employmentSchool}');
    } else if (person.employmentIsSelfEmployed) {
      print('  self-employed');
    }
  }
}
