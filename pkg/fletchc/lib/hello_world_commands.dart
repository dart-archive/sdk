// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.hello_world_commands;

import 'commands.dart';

const List<Command> commands = const <Command>[
    const Generic(Opcode.NewMap, const [1, 0, 0, 0]),
    const Generic(Opcode.NewMap, const [0, 0, 0, 0]),
    const Generic(Opcode.NewMap, const [2, 0, 0, 0]),

    const Generic(Opcode.PushNull, const []),
    const Generic(Opcode.PushNull, const []),
    const Generic(Opcode.PushNull, const []),

    const Generic(
        Opcode.PushNewFunction,
        const [
            1, 0, 0, 0, 3, 0, 0, 0, 31, 0, 0, 0, 9, 0, 0, 0, 0, 23, 1, 0, 0, 0,
            45, 18, 23, 2, 0, 0, 0, 45, 14, 46, 1, 1, 71, 22, 0, 0, 0, 0, 0, 0,
            0
        ]),

    const PopToMap(0, 0),

    const Generic(
        Opcode.PushNewFunction,
        const [
            1, 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 0, 26, 1, 0, 61, 71, 4, 0, 0, 0,
            0, 0, 0, 0
        ]),

    const PopToMap(0, 1),

    const Generic(
        Opcode.PushNewFunction,

        const [
            1, 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 0, 26, 1, 1, 61, 71, 4, 0, 0, 0,
            0, 0, 0, 0
        ]),

    const PopToMap(0, 2),

    const Generic(
        Opcode.ChangeStatics,
        const [0, 0, 0, 0]),

    const Generic(
        Opcode.PushNull,
        const []),

    const PopToMap(2, 0),

    const Generic(
        Opcode.PushBoolean,
        const [1]),

    const PopToMap(2, 1),

    const Generic(
        Opcode.PushBoolean,
        const [0]),

    const PopToMap(2, 2),

    const PushNewString("Hej Verden!"),

    const PopToMap(2, 3),

    const Generic(
        Opcode.PushFromMap,
        const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),

    const Generic(
        Opcode.PushFromMap,
        const [2, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0]),

    const Generic(
        Opcode.ChangeMethodLiteral,
        const [0, 0, 0, 0]),

    const Generic(
        Opcode.PushFromMap,
        const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),

    const Generic(
        Opcode.PushFromMap,
        const [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]),

    const Generic(
        Opcode.ChangeMethodLiteral,
        const [1, 0, 0, 0]),

    const Generic(
        Opcode.PushFromMap,
        const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),

    const Generic(
        Opcode.PushFromMap,
        const [0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0]),

    const Generic(
        Opcode.ChangeMethodLiteral,
        const [2, 0, 0, 0]),

    const Generic(
        Opcode.CommitChanges,
        const [4, 0, 0, 0]),

    const Generic(
        Opcode.PushNewInteger,
        const [0, 0, 0, 0, 0, 0, 0, 0]),

    const Generic(
        Opcode.PushFromMap,
        const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),

    const Generic(
        Opcode.RunMain,
        const []),

    const Generic(
        Opcode.SessionEnd,
        const []),
];
