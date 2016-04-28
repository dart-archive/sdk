// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_system_validator;

import '../dartino_system.dart' show
    DartinoConstant,
    DartinoFunction,
    DartinoSystem;

import '../dartino_class.dart' show
    DartinoClass;

import 'package:dartino_compiler/vm_commands.dart' show
    MapId;

class DartinoSystemValidator {
  final DartinoSystem system;

  DartinoSystemValidator(this.system);

  bool validateClassMethodTables() {
    return system.classesById.values.fold(true,(bool res, DartinoClass cls) {
      return validateMethodTable(cls) && res;
    });
  }

  bool validateMethodTable(DartinoClass cls) {
    return cls.methodTable.values.fold(true, (bool res, int id) {
      if (system.lookupFunctionById(id) == null) {
        print("Could not find method with id $id from table of $cls");
        return false;
      }
      return res;
    });
  }

  bool validateFunctionLiteralLists() {
    return system.functionsById.values.
        fold(true, (bool res, DartinoFunction function) {
      return validateLiteralList(function) && res;
    });
  }

  bool validateLiteralList(DartinoFunction function) {

    bool reportNotFound(DartinoConstant constant) {
       print("Could not find $constant from literal list of $function");
       return false;
    }

    return function.constants.fold(true, (bool res, DartinoConstant constant) {
      if (constant.mapId == MapId.constants) {
        if (system.lookupConstantById(constant.id) == null) {
          return reportNotFound(constant);
        }
      } else if (constant.mapId == MapId.methods) {
        if (system.lookupFunctionById(constant.id) == null) {
          return reportNotFound(constant);
        }
      } else if (system.lookupClassById(constant.id) == null) {
        return reportNotFound(constant);
      }
      return res;
    });
  }
}