// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library todomvc.presenter_mirror_dart;

import 'presenter_model.dart';

// Presentation mirror uses (possibly mutable) host structures. For this demo we
// just reuse the "dart" side model and mutate that.  In the end we want to
// generate a native representation mirroring the "presentation model".

class Mirror {

  // Hack alert!
  /*A mutable*/ Immutable root = new Nil();

  List<Command> cmds = new List();

  void apply(PatchSet patches) {
    for (Patch patch in patches.patches) {
      Cons prev = null;
      Immutable current = root;
      Path context = null;
      Path path = patch.path;
      while (path != null) {
        trace("apply: path($path), current($current)");
        context = path;
        path = path.parent;
        prev = current;
        if (context is ConsFst) {
          current = prev.fst;
          if (path == null) {
            trace("apply: replacing fst(${prev.fst}) by ${patch.content}");
            prev.fst = patch.content;
          } else {
            trace("apply: stepping fst");
          }
        } else if (context is ConsSnd) {
          current = prev.snd;
          if (path == null) {
            trace("apply: replacing snd(${prev.snd}) by ${patch.content}");
            prev.snd = patch.content;
          } else {
            trace("apply: stepping snd");
          }
        } else {
          throw new Exception("Invalid path $context");
        }
      }
      // Special case to replace the root node
      if (context == null) {
        trace("apply: replacing root(${root}) by ${patch.content}");
        root = patch.content;
      }
    }
  }

  void create(String title) {
    cmds.add(new CreateCommand(new Str(title)));
  }

  void delete(int id) {
    cmds.add(new DeleteCommand(id));
  }

  void complete(int id) {
    cmds.add(new CompleteCommand(id));
  }

  void clear() {
    cmds.add(new ClearCommand());
  }

}
