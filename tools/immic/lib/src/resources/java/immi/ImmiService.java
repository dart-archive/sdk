// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package immi;

import java.util.HashMap;
import java.util.Map;

import dartino.ImmiServiceLayer;
import dartino.MessageBuilder;
import dartino.PresenterDataBuilder;
import dartino.Uint16ListBuilder;

public final class ImmiService {

  public ImmiRoot registerPresenter(AnyNodePresenter presenter, String name) {
    assert !roots.containsKey(name);
    int length = name.length();
    int space = 48 + PresenterDataBuilder.kSize + length;
    MessageBuilder message = new MessageBuilder(space);
    PresenterDataBuilder builder = new PresenterDataBuilder();
    message.initRoot(builder, PresenterDataBuilder.kSize);
    Uint16ListBuilder chars = builder.initNameData(length);
    for (int i = 0; i < length; ++i) chars.set(i, name.charAt(i));
    int id = ImmiServiceLayer.getPresenter(builder);
    ImmiRoot root = new ImmiRoot(id, presenter);
    roots.put(name, root);
    return root;
  }

  private Map<String, ImmiRoot> roots = new HashMap<String, ImmiRoot>();
}
