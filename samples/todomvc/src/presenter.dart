// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library todomvc.presenter;

import 'dart:typed_data';

import 'presenter_model.dart';

abstract class Presenter {
  var _client;
  var _presentation = new Nil();

  Presenter(this._client);

  // The render method constructs a "presenter model" from the model.  The
  // result is compared to the previous "presenter model" to calculate the patch
  // sets for the host.
  Immutable render();

  // Apply a UI initiated command. This should be replaced by a direct call to a
  // method on the presenter as defined by the yet-to-be description language.
  void applyCommand(Command);

  // Main loop on the Dart side. Reads and applies commands and then renders
  // with the updated model and finally computes a diff of the immutable
  // "presenter model".  The patches are then issued back to the host.
  void run() {
    trace("Starting up presenter");
    int iteration = 0;
    while (_readCommands() && _writePatches()) {
      trace("Completed sync iteration ${++iteration}");
    }
    trace("Shutting down presenter");
    _client.close();
  }

  bool _readCommands() {
    // Read and run commands.
    trace("Reading command count");
    var buffer = _client.read(4);
    if (buffer == null) {
      return false;
    }
    var data = new ByteData.view(buffer);
    final length = getUint32(data, 0);
    trace("Reading ${length} bytes of commands");
    buffer = _client.read(length);
    if (buffer == null) {
      return false;
    }
    data = new ByteData.view(buffer);
    int offset = 0;
    while (offset < length) {
      Result cmdRes = Command.deserialize(data, offset);
      offset += cmdRes.offset;
      trace("Applying command");
      applyCommand(cmdRes.result);
    }
    return true;
  }

  bool _writePatches() {
    // Render model and calculate patches.
    trace("Rendering and diff'ing");
    PatchSet patches = new PatchSet();
    _presentation = render()..diff(_presentation, null, patches);
    trace("Patch set items ${patches.patches.length}");
    // Write patches.
    ByteData data = serializeList(patches.patches);
    trace("Patch set bytes ${data.lengthInBytes}");
    _client.write(data.buffer);

    for (Patch patch in patches.patches) {
      trace("{ path: ${patch.path}, content: ${patch.content} }");
    }

    return true;
  }
}

class TodoListPresenter extends Presenter {

  Model _model;

  TodoListPresenter(this._model, client) : super(client);

  Immutable render() {
    Immutable list = new Nil();
    for (var i = _model.todos.length; i > 0; ) {
      list = new Cons(_reprItem(_model.todos[--i]), list);
    }
    return list;
  }

  void applyCommand(Command cmd) {
    switch (cmd.tag) {
      case TAG_CREATE: _model.createItem(cmd.title.value); break;
      case TAG_DELETE: _model.deleteItem(cmd.id); break;
      case TAG_COMPLETE: _model.completeItem(cmd.id); break;
      case TAG_CLEAR: _model.clearItems(); break;
    }
  }

  Immutable _reprItem(Item item) =>
      new Cons(new Str(item.title),
               new Bool(item.done));

}
