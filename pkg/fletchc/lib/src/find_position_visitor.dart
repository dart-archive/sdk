// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:compiler/src/elements/visitor.dart';
import 'package:compiler/src/scanner/scannerlib.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/elements/modelx.dart';

class FindPositionVisitor extends BaseElementVisitor {
  final int position;
  Element element;

  FindPositionVisitor(this.position, this.element);

  visit(Element e, [arg]) => e.accept(this, arg);

  visitElement(ElementX e, _) {
    DeclarationSite site = e.declarationSite;
    if (site is PartialElement) {
      if (site.beginToken.charOffset <= position &&
          position < site.endToken.next.charOffset) {
        element = e;
      }
    }
  }

  visitClassElement(ClassElement e, _) {
    if (e is PartialClassElement) {
      if (e.beginToken.charOffset <= position &&
          position < e.endToken.next.charOffset) {
        element = e;
        visitScopeContainerElement(e, null);
      }
    }
  }

  visitScopeContainerElement(ScopeContainerElement e, _) {
    e.forEachLocalMember((Element element) => visit(element));
  }

  visitCompilationUnitElement(CompilationUnitElement e, _) {
    e.forEachLocalMember((Element element) => visit(element));
  }
}
