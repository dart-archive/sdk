// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package immi;

public interface NodePresenter<N extends Node, P extends NodePatch> {
  void present(N node);
  void patch(P patch);
}
