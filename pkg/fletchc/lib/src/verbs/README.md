<!---
Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
for details. All rights reserved. Use of this source code is governed by a
BSD-style license that can be found in the LICENSE.md file.
-->

# Design for Fletch Command Line Interface commands

The overall structure of commands in Fletch should follow:

```
fletch verb [zero or more verbs or object-nouns]
```

The outermost verb is the group of actions to be performed 
(for example, 'help'). Subsequent verbs are either 'sub-verbs'
(for example, 'debug step') or are the target of the outer verbs 
(for example 'help debug').

Object-nouns are the target of the command (for example, 'fletch show changes')

The overall aim here is to provide the ability to 'vocalise' the instructions,
in other words to say them to yourself as you type them.

## Some examples

```
fletch debug step
```

should perform the next step of execution. 

```
fletch help
```

should provide 'top level' help, whereas:

```
fletch help debug
```
should provide help about debug.


## Exceptions

Help should be supported everywhere as a top level verb and a sub-verb,
in other words:

```
fletch help debug
```
       and
```
fletch debug help
```

Should display the same text.
