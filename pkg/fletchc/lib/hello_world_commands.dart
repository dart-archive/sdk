// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.hello_world_commands;

import 'commands.dart';

const List<Command> commands = const <Command>[
    const NewMap(MapId.methods),
    const NewMap(MapId.constants),

    const PushNull(),
    const PushNull(),
    const PushNull(),

    const PushNewFunction(
        1, 3,
        const [
            9, 0, 0, 0, 0, 23, 1, 0, 0, 0, 45, 18, 23, 2, 0, 0, 0, 45, 14, 46,
            1, 1, 71, 22, 0, 0, 0, 0, 0, 0, 0
        ]),

    const PopToMap(MapId.methods, 0),

    const PushNewFunction(
        1, 0, const [26, 1, 0, 61, 71, 4, 0, 0, 0, 0, 0, 0, 0]),

    const PopToMap(MapId.methods, 1),

    const PushNewFunction(
        1, 0, const [26, 1, 1, 61, 71, 4, 0, 0, 0, 0, 0, 0, 0]),

    const PopToMap(MapId.methods, 2),

    const ChangeStatics(0),

    const PushNull(),

    const PopToMap(MapId.constants, 0),

    const PushBoolean(true),

    const PopToMap(MapId.constants, 1),

    const PushBoolean(false),

    const PopToMap(MapId.constants, 2),

    const PushNewString("Hej Verden!"),

    const PopToMap(MapId.constants, 3),

    const PushFromMap(MapId.methods, 0),

    const PushFromMap(MapId.constants, 3),

    const ChangeMethodLiteral(0),

    const PushFromMap(MapId.methods, 0),

    const PushFromMap(MapId.methods, 1),

    const ChangeMethodLiteral(1),

    const PushFromMap(MapId.methods, 0),

    const PushFromMap(MapId.methods, 2),

    const ChangeMethodLiteral(2),

    const CommitChanges(4),

    const PushNewInteger(0),

    const PushFromMap(MapId.methods, 0),

    const RunMain(),

    const SessionEnd(),
];
