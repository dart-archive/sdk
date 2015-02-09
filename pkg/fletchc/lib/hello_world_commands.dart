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

    // method @1: _printString
    //    0: invoke native 1 0
    //    3: throw
    //    4: method end 4
    const PushNewFunction(
        1, 0, const [26, 1, 0, 61, 71, 4, 0, 0, 0, 0, 0, 0, 0]),

    // method @2: _halt
    //    0: invoke native 1 1
    //    3: throw
    //    4: method end 4
    const PushNewFunction(
        1, 0, const [26, 1, 1, 61, 71, 4, 0, 0, 0, 0, 0, 0, 0]),

    // method @0: _entry
    //    0: load const @0
    //    5: invoke static @1
    //   10: pop
    //   11: load literal 1
    //   12: invoke static @2
    //   17: pop
    //   18: load literal null
    //   19: return 1 1
    //   22: method end 22
    const PushNewFunction(
        1, 3,
        const [
            9, 0, 0, 0, 0, 23, 1, 0, 0, 0, 45, 18, 23, 2, 0, 0, 0, 45, 14, 46,
            1, 1, 71, 22, 0, 0, 0, 0, 0, 0, 0
        ]),

    const RunMain(),

    const SessionEnd(),
];
