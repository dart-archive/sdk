// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino_compiler.incremental.diff;

import 'package:compiler/src/elements/elements.dart' show
    AbstractFieldElement,
    ClassElement,
    CompilationUnitElement,
    Element,
    ElementCategory,
    FunctionElement,
    LibraryElement,
    ScopeContainerElement;

import 'package:compiler/src/elements/modelx.dart' as modelx;

import 'package:compiler/src/elements/modelx.dart' show
    DeclarationSite;

import 'package:compiler/src/tokens/token_constants.dart' show
    EOF_TOKEN,
    IDENTIFIER_TOKEN,
    KEYWORD_TOKEN;

import 'package:compiler/src/tokens/token.dart' show
    ErrorToken,
    Token;

import 'package:compiler/src/parser/partial_elements.dart' show
    PartialClassElement,
    PartialElement;

import 'dartino_compiler_incremental.dart' show
    IncrementalCompilationFailed;

class Difference {
  final DeclarationSite before;
  final DeclarationSite after;

  /// Records the position of first difference between [before] and [after]. If
  /// either [before] or [after] are null, [token] is null.
  Token token;

  Difference(this.before, this.after) {
    if (before == after) {
      throw '[before] and [after] are the same.';
    }
  }

  String toString() {
    if (before == null) return 'Added($after)';
    if (after == null) return 'Removed($before)';
    return 'Modified($after -> $before)';
  }
}

void checkCanComputeDifference(modelx.ElementX element) {
  if (element.isMixinApplication) {
    // TODO(ahe): issue 91
    throw new IncrementalCompilationFailed(
        "Mixin applications not supported: $element");
  }
  if (element.isClass) {
    modelx.ClassElementX cls = element;
    if (cls.isEnumClass) {
      throw new IncrementalCompilationFailed("Enums not supported: $element");
    }
  }
  if (element.declarationSite == null && !element.isSynthesized) {
    throw new IncrementalCompilationFailed(
        "Unable to compute diff for $element");
  }
}

List<Difference> computeDifference(
    ScopeContainerElement before,
    ScopeContainerElement after) {
  Map<String, DeclarationSite> beforeMap = <String, DeclarationSite>{};
  before.forEachLocalMember((modelx.ElementX element) {
    checkCanComputeDifference(element);
    DeclarationSite site = element.declarationSite;
    assert(site != null || element.isSynthesized);
    if (!element.isSynthesized) {
      beforeMap[element.name] = site;
    }
  });
  List<Difference> modifications = <Difference>[];
  List<Difference> potentiallyChanged = <Difference>[];
  after.forEachLocalMember((modelx.ElementX element) {
    checkCanComputeDifference(element);
    DeclarationSite existing = beforeMap.remove(element.name);
    if (existing == null) {
      if (!element.isSynthesized) {
        modifications.add(new Difference(null, element.declarationSite));
      }
    } else {
      potentiallyChanged.add(new Difference(existing, element.declarationSite));
    }
  });

  modifications.addAll(
      beforeMap.values.map(
          (DeclarationSite site) => new Difference(site, null)));

  modifications.addAll(
      potentiallyChanged.where(areDifferentElements));

  return modifications;
}

bool areDifferentElements(Difference diff) {
  DeclarationSite before = diff.before;
  DeclarationSite after = diff.after;
  if (before is PartialElement && after is PartialElement) {
    Token beforeToken = before.beginToken;
    Token afterToken = after.beginToken;
    Token stop = before.endToken;
    int beforeKind = beforeToken.kind;
    int afterKind = afterToken.kind;
    while (beforeKind != EOF_TOKEN && afterKind != EOF_TOKEN) {

      if (beforeKind != afterKind) {
        diff.token = afterToken;
        return true;
      }

      if (beforeToken is! ErrorToken && afterToken is! ErrorToken) {
        if (beforeToken.value != afterToken.value) {
          diff.token = afterToken;
          return true;
        }
      }

      if (beforeToken == stop) {
        diff.token = afterToken;
        // We didn't find a difference, and normally that would mean that the
        // element hasn't changed. However, for elements with members, the
        // situation is more tricky. For example, consider a class that never
        // has any changes to its header (everything before the first `{`). The
        // tokens of this class aren't patched up if one of its members
        // change. So we can't actually look at the tokens of the class to see
        // if one of its members changed. Instead, we must say that the class
        // changed, and then look at its members one by one.
        return before is ScopeContainerElement;
      }

      beforeToken = beforeToken.next;
      afterToken = afterToken.next;
      beforeKind = beforeToken.kind;
      afterKind = afterToken.kind;
    }
    return beforeKind != afterKind;
  }
  print("$before isn't a PartialElement");
  return true;
}
