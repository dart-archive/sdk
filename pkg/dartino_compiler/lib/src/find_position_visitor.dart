// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:compiler/src/elements/visitor.dart';
import 'package:compiler/src/parser/partial_elements.dart';
import 'package:compiler/src/elements/elements.dart';
import 'package:compiler/src/tree/nodes.dart';

/// Returns the innermost function in [compilationUnit] spanning [position] or
/// [null] if no such function is found.
findFunctionAtPosition(CompilationUnitElement compilationUnit, int position) {
  FindFunctionAtPositionVisitor visitor =
      new FindFunctionAtPositionVisitor(position);
  visitor.visit(compilationUnit);
  return visitor.element;
}

class FindFunctionAtPositionVisitor extends BaseElementVisitor {
  final int position;
  FunctionElement element;

  FindFunctionAtPositionVisitor(this.position);

  visitFunctionElement(FunctionElement function, _) {
    if (containsPosition(function.node)) {
      element = function;
      MemberElement memberElement = function.memberContext;
      if (memberElement == function) {
        element = findSmallestMatchingClosure(memberElement) ?? element;
      }
    }
  }

  FunctionElement findSmallestMatchingClosure(MemberElement memberElement) {
    FunctionElement smallest;
    for (FunctionElement closure in memberElement.nestedClosures) {
      if (!containsPosition(closure.node)) continue;
      if (smallest == null ||
          nodeLength(closure.node) < nodeLength(smallest.node)) {
        smallest = closure;
      }
    }
    return smallest;
  }

  visitClassElement(ClassElement element, _) {
    if (element is PartialClassElement) {
      if (element.beginToken.charOffset <= position &&
          position < element.endToken.next.charOffset) {
        element.forEachLocalMember(visit);
      }
    }
  }

  visitCompilationUnitElement(CompilationUnitElement element, _) {
    element.forEachLocalMember(visit);
  }

  visitFieldElement(FieldElement e, _) {
    element = findSmallestMatchingClosure(e) ?? element;
  }


  visit(Element e, [arg]) => e.accept(this, arg);

  visitElement(Element element, _) {}

  bool containsPosition(Node node) {
    // TODO(sigurdm): Find out when [node] is null.
    if (node == null) return false;
    return node.getBeginToken().charOffset <= position &&
        position < node.getEndToken().charEnd;
  }

  static int nodeLength(Node node) {
    return node.getEndToken().charEnd - node.getBeginToken().charOffset;
  }
}
