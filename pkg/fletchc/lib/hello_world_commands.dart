// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.hello_world_commands;

import 'commands.dart';

import 'bytecodes.dart';

const List<Command> commands = const <Command>[
    const ChangeStatics(0),

    const CommitChanges(1),

    const PushNewInteger(0),

    const PushNewString("Hej Verden!"),

    // method @1: _printString
    const PushNewFunction(
        1, 0,
        const <Bytecode>[
            const InvokeNative(1, 0),
            const Throw(),
        ]),

    // method @2: _halt
    const PushNewFunction(
        1, 0,
        const <Bytecode>[
            const InvokeNative(1, 1),
            const Throw(),
        ]),

    // method @0: _entry
    const PushNewFunction(
        1, 3,
        const [
            const LoadConstUnfold(0),
            const InvokeStaticUnfold(1),
            const Pop(),
            const LoadLiteral1(),
            const InvokeStaticUnfold(2),
            const Pop(),
            const LoadLiteralNull(),
            const Return(1, 1),
        ]),

    const RunMain(),

    const SessionEnd(),
];
