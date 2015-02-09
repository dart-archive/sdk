// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.hello_world_commands;

import 'commands.dart';

const List<Command> commands = const <Command>[
    const ChangeStatics(0),

    const CommitChanges(1),

    const PushNewInteger(0),

    const PushNewString("Hej Verden!"),

    const PushNewFunction(
        1, 0, const [26, 1, 0, 61, 71, 4, 0, 0, 0, 0, 0, 0, 0]),

    const PushNewFunction(
        1, 0, const [26, 1, 1, 61, 71, 4, 0, 0, 0, 0, 0, 0, 0]),

    const PushNewFunction(
        1, 3,
        const [
            9, 0, 0, 0, 0, 23, 1, 0, 0, 0, 45, 18, 23, 2, 0, 0, 0, 45, 14, 46,
            1, 1, 71, 22, 0, 0, 0, 0, 0, 0, 0
        ]),

    const RunMain(),

    const SessionEnd(),
];
