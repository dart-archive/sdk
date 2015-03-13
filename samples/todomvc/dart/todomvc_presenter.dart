// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Should become auto-generated.

library todomvc_presenter;

import 'todomvc_service.dart';
import 'todomvc_presenter_model.dart';

abstract class TodoMVCPresenter extends TodoMVCService {

  var _presentation = new Nil();

  // Construct a "presenter model" from the model.
  Immutable render();

  // Compare two "presenter models" to calculate a patch set for the host.
  MyPatchSet diff(Immutable previous, Immutable current) {
    var patchSet = new MyPatchSet();
    current.diff(previous, null, patchSet);
    for (var patch in patchSet.patches) {
      trace("{ path: ${patch.path}, content: ${patch.content} }");
    }
    return patchSet;
  }

  // Update the presentation and get the current patch set.
  MyPatchSet update() {
    var previous = _presentation;
    _presentation = render();
    return diff(previous, _presentation);
  }

  // Entry point for synchronizing with the host mirror.
  void sync(PatchSetBuilder result) {
    update().serialize(result);
  }

  void reset() {
    _presentation = new Nil();
  }

}