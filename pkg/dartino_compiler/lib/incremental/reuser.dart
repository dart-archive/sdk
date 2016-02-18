// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino_compiler_incremental.reuser;

import 'dart:async' show
    Future;

import 'package:compiler/compiler.dart' as api;

import 'package:compiler/src/compiler.dart' show
    Compiler;

import 'package:compiler/src/diagnostics/messages.dart' show
    MessageKind;

import 'package:compiler/src/script.dart' show
    Script;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    CompilationUnitElement,
    Element,
    LibraryElement,
    STATE_NOT_STARTED,
    ScopeContainerElement,
    TypeDeclarationElement;

import 'package:compiler/src/tokens/token_constants.dart' show
    EOF_TOKEN;

import 'package:compiler/src/tokens/token.dart' show
    Token;

import 'package:compiler/src/parser/partial_elements.dart' show
    PartialClassElement,
    PartialElement,
    PartialFieldList,
    PartialFunctionElement;

import 'package:compiler/src/scanner/scanner.dart' show
    Scanner;

import 'package:compiler/src/parser/parser.dart' show
    Parser;

import 'package:compiler/src/parser/listener.dart' show
    Listener;

import 'package:compiler/src/parser/node_listener.dart' show
    NodeListener;

import 'package:compiler/src/io/source_file.dart' show
    CachingUtf8BytesSourceFile,
    SourceFile,
    StringSourceFile;

import 'package:compiler/src/tree/tree.dart' show
    ClassNode,
    FunctionExpression,
    LibraryTag,
    NodeList,
    unparse;

import 'package:compiler/src/util/util.dart' show
    Link;

import 'package:compiler/src/elements/modelx.dart' show
    ClassElementX,
    CompilationUnitElementX,
    DeclarationSite,
    ElementX,
    FieldElementX,
    LibraryElementX;

import 'package:compiler/src/constants/values.dart' show
    ConstantValue;

import 'package:compiler/src/library_loader.dart' show
    TagState;

import '../incremental_backend.dart' show
    IncrementalBackend;

import 'diff.dart' show
    Difference,
    computeDifference;

import 'dartino_compiler_incremental.dart' show
    IncrementalCompilationFailed;

typedef void Logger(message);

typedef bool ReuseFunction(
    Token diffToken,
    PartialElement before,
    PartialElement after);

class FailedUpdate {
  /// Either an [Element] or a [Difference].
  final context;
  final String message;

  FailedUpdate(this.context, this.message);

  String toString() {
    if (context == null) return '$message';
    return 'In $context:\n  $message';
  }
}

abstract class Reuser {
  final Compiler compiler;

  final api.CompilerInputProvider inputProvider;

  final Logger logTime;

  final Logger logVerbose;

  final List<Update> updates = <Update>[];

  final List<FailedUpdate> _failedUpdates = <FailedUpdate>[];

  final Set<ElementX> _elementsToInvalidate = new Set<ElementX>();

  final Set<ElementX> _removedElements = new Set<ElementX>();

  final Map<Uri, Future> _sources = <Uri, Future>{};

  /// Cached tokens of entry compilation units.
  final Map<LibraryElementX, Token> _entryUnitTokens =
      <LibraryElementX, Token>{};

  /// Cached source files for entry compilation units.
  final Map<LibraryElementX, SourceFile> _entrySourceFiles =
      <LibraryElementX, SourceFile>{};

  final Map<LibraryElement, Future<LibraryElement>> _cachedLibraryCopyFutures =
      <LibraryElement, Future<LibraryElement>>{};

  final Map<LibraryElement, LibraryElement> _cachedLibraryCopies =
      <LibraryElement, LibraryElement>{};

  final Set<LibraryElement> _synthesizedLibraries = new Set<LibraryElement>();

  Reuser(
      this.compiler,
      this.inputProvider,
      this.logTime,
      this.logVerbose);

  IncrementalBackend get backend;

  /// When [true], updates must be applied (using [applyUpdates]) before the
  /// [compiler]'s state correctly reflects the updated program.
  bool get hasPendingUpdates => updates.isNotEmpty;

  bool get failed => _failedUpdates.isNotEmpty;

  /// Used as tear-off passed to [LibraryLoaderTask.resetLibraries].
  Future<Iterable<LibraryElement>> reuseLibraries(
      Iterable<LibraryElement> libraries) async {
    List<LibraryElement> reusedLibraries = <LibraryElement>[];
    for (LibraryElement library in libraries) {
      if (await _reuseLibrary(library)) {
        reusedLibraries.add(library);
      }
    }
    return reusedLibraries;
  }

  Future<bool> _reuseLibrary(LibraryElement library) async {
    assert(compiler != null);
    if (library.isPlatformLibrary) {
      logTime('Reusing $library (assumed read-only).');
      return true;
    }
    LibraryElement newLibrary;
    try {
      if (await _haveTagsChanged(library)) {
        cannotReuse(
            library,
            "Changes to library, import, export, or part declarations not"
            " supported.");
        // We return true to here to avoid that the library loader tries to
        // load a different version of this library.
        return true;
      }

      logTime('Attempting to reuse ${library}.');
      newLibrary = await copyLibraryWithChanges(library);
    } finally {
      _cleanUp(library);
    }
    if (newLibrary == library) {
      logTime("Reusing $library, source didn't change.");
      return true;
    } else {
      logTime('New library synthesized.');
      return canReuseScopeContainerElement(library, newLibrary);
    }
  }

  Future<bool> _computeUpdatedScripts(
      LibraryElement library,
      List<Script> scripts) async {
    bool isChanged = false;
    for (CompilationUnitElementX unit in library.compilationUnits) {
      Uri uri = unit.script.resourceUri;
      if (uriHasUpdate(uri)) {
        isChanged = true;
        scripts.add(await _updatedScript(unit.script, library));
      } else {
        scripts.add(unit.script);
      }
    }
    return new Future<bool>.value(isChanged);
  }

  void _cleanUp(LibraryElementX library) {
    _entryUnitTokens.remove(library);
    _entrySourceFiles.remove(library);
  }

  Future<Script> _updatedScript(Script before, LibraryElementX library) {
    if (before == library.entryCompilationUnit.script &&
        _entrySourceFiles.containsKey(library)) {
      return new Future.value(before.copyWithFile(_entrySourceFiles[library]));
    }

    return _readUri(before.resourceUri).then((bytes) {
      Uri uri = before.file.uri;
      String filename = before.file.filename;
      SourceFile sourceFile = bytes is String
          ? new StringSourceFile(uri, filename, bytes)
          : new CachingUtf8BytesSourceFile(uri, filename, bytes);
      return before.copyWithFile(sourceFile);
    });
  }

  Future<bool> _haveTagsChanged(LibraryElementX library) {
    Script before = library.entryCompilationUnit.script;
    if (!uriHasUpdate(before.resourceUri)) {
      // The entry compilation unit hasn't been updated. So the tags aren't
      // changed.
      return new Future<bool>.value(false);
    }

    return _updatedScript(before, library).then((Script script) {
      _entrySourceFiles[library] = script.file;
      Token token = new Scanner(_entrySourceFiles[library]).tokenize();
      _entryUnitTokens[library] = token;
      // Using two parsers to only create the nodes we want ([LibraryTag]).
      Parser parser = new Parser(new Listener());
      Element entryCompilationUnit = library.entryCompilationUnit;
      NodeListener listener = new NodeListener(
          compiler.resolution.parsing
              .getScannerOptionsFor(entryCompilationUnit),
          compiler.reporter, entryCompilationUnit);
      Parser nodeParser = new Parser(listener);
      Iterator<LibraryTag> tags = library.tags.iterator;
      while (token.kind != EOF_TOKEN) {
        token = parser.parseMetadataStar(token);
        if (parser.optional('library', token) ||
            parser.optional('import', token) ||
            parser.optional('export', token) ||
            parser.optional('part', token)) {
          if (!tags.moveNext()) return true;
          token = nodeParser.parseTopLevelDeclaration(token);
          LibraryTag tag = listener.popNode();
          assert(listener.nodes.isEmpty);
          if (unparse(tags.current) != unparse(tag)) {
            return true;
          }
        } else {
          break;
        }
      }
      return tags.moveNext();
    });
  }

  Future _readUri(Uri uri) {
    return _sources.putIfAbsent(uri, () => inputProvider(uri));
  }

  LibraryElement _synthesizeLibrary(
      LibraryElement library,
      List<Script> scripts) {
    Uri entryUri = library.entryCompilationUnit.script.resourceUri;
    Script entryScript =
        scripts.singleWhere((Script script) => script.resourceUri == entryUri);
    LibraryElementX newLibrary =
        new LibraryElementX(entryScript, library.canonicalUri);
    if (_entryUnitTokens.containsKey(library)) {
      compiler.dietParser.dietParse(
          newLibrary.entryCompilationUnit, _entryUnitTokens[library]);
    } else {
      compiler.scanner.scanLibrary(newLibrary);
    }

    TagState tagState = new TagState();
    for (LibraryTag tag in newLibrary.tags) {
      if (tag.isImport) {
        tagState.checkTag(TagState.IMPORT_OR_EXPORT, tag, compiler.reporter);
      } else if (tag.isExport) {
        tagState.checkTag(TagState.IMPORT_OR_EXPORT, tag, compiler.reporter);
      } else if (tag.isLibraryName) {
        tagState.checkTag(TagState.LIBRARY, tag, compiler.reporter);
        if (newLibrary.libraryTag == null) {
          // Use the first if there are multiple (which is reported as an
          // error in [TagState.checkTag]).
          newLibrary.libraryTag = tag;
        }
      } else if (tag.isPart) {
        tagState.checkTag(TagState.PART, tag, compiler.reporter);
      }
    }

    Link<CompilationUnitElement> units = library.compilationUnits;
    for (Script script in scripts) {
      CompilationUnitElementX unit = units.head;
      units = units.tail;
      if (script != entryScript) {
        // TODO(ahe): Copied from library_loader.
        CompilationUnitElement newUnit =
            new CompilationUnitElementX(script, newLibrary);
        compiler.reporter.withCurrentElement(newUnit, () {
          compiler.scanner.scan(newUnit);
          if (unit.partTag == null) {
            compiler.reporter.reportErrorMessage(
                unit, MessageKind.MISSING_PART_OF_TAG);
          }
        });
      }
    }

    // Record that this library is synthetic.
    _synthesizedLibraries.add(newLibrary);

    return newLibrary;
  }

  /// Returns true if [library] is synthetic, that is, created with
  /// [_synthesizeLibrary] above.
  bool isSynthetic(LibraryElement library) {
    return _synthesizedLibraries.contains(library);
  }

  /// Returns a copy of [library] if any of its parts have changed, whose token
  /// positions represent the changed positions.  If [library] hasn't changed,
  /// it's returned unmodified.
  Future<LibraryElement> copyLibraryWithChanges(LibraryElement library) {
    return _cachedLibraryCopyFutures.putIfAbsent(library, () async {
      List<Script> scripts = <Script>[];
      if (!await _computeUpdatedScripts(library, scripts)) {
        _cachedLibraryCopies[library] = library;
        return library;
      }
      try {
        LibraryElement copy = _synthesizeLibrary(library, scripts);
        _cachedLibraryCopies[library] = copy;
        return copy;
      } finally {
        _cleanUp(library);
      }
    });
  }

  /// Same as [copyLibraryWithChanges], but synchronous. Relies on
  /// [copyLibraryWithChanges] was called previously.
  LibraryElement copyLibraryWithChangesSync(LibraryElement library) {
    LibraryElement copy = _cachedLibraryCopies[library];
    return copy == null ? library : copy;
  }

  bool cannotReuse(context, String message) {
    _failedUpdates.add(new FailedUpdate(context, message));
    logVerbose(message);
    return false;
  }

  bool canReuseScopeContainerElement(
      ScopeContainerElement element,
      ScopeContainerElement newElement) {
    if (checkForGenericTypes(element)) return false;
    if (checkForGenericTypes(newElement)) return false;
    List<Difference> differences = computeDifference(element, newElement);
    logTime('Differences computed.');
    for (Difference difference in differences) {
      logTime('Looking at difference: $difference');

      if (difference.before == null && difference.after is PartialElement) {
        canReuseAddedElement(difference.after, element, newElement);
        continue;
      }
      if (difference.after == null && difference.before is PartialElement) {
        canReuseRemovedElement(difference.before, element);
        continue;
      }
      Token diffToken = difference.token;
      if (diffToken == null) {
        cannotReuse(difference, "No difference token.");
        continue;
      }
      if (difference.after is! PartialElement &&
          difference.before is! PartialElement) {
        cannotReuse(difference, "Don't know how to recompile.");
        continue;
      }
      PartialElement before = difference.before;
      PartialElement after = difference.after;

      ReuseFunction reuser;

      if (before is PartialFunctionElement && after is PartialFunctionElement) {
        reuser = canReuseFunction;
      } else if (before is PartialClassElement &&
                 after is PartialClassElement) {
        reuser = canReuseClass;
      } else {
        reuser = unableToReuse;
      }
      if (!reuser(diffToken, before, after)) {
        assert(_failedUpdates.isNotEmpty);
        continue;
      }
    }

    return _failedUpdates.isEmpty;
  }

  bool canReuseAddedElement(
      PartialElement element,
      ScopeContainerElement container,
      ScopeContainerElement syntheticContainer) {
    if (!allowAddedElement(element)) return false;
    if (element is PartialFunctionElement) {
      addFunction(element, container);
      return true;
    } else if (element is PartialClassElement) {
      addClass(element, container);
      return true;
    } else if (element is PartialFieldList) {
      addFields(element, container, syntheticContainer);
      return true;
    }
    return cannotReuse(element, "Adding ${element.runtimeType} not supported.");
  }

  void addFunction(
      PartialFunctionElement element,
      /* ScopeContainerElement */ container) {
    invalidateScopesAffectedBy(element, container);

    addAddedFunctionUpdate(compiler, element, container);
  }

  void addClass(
      PartialClassElement element,
      LibraryElementX library) {
    invalidateScopesAffectedBy(element, library);

    addAddedClassUpdate(compiler, element, library);
  }

  /// Called when a field in [definition] has changed.
  ///
  /// There's no direct link from a [PartialFieldList] to its implied
  /// [FieldElementX], so instead we use [syntheticContainer], the (synthetic)
  /// container created by [copyLibraryWithChanges], or [canReuseClass]
  /// (through [PartialClassElement.parseNode]). This container is scanned
  /// looking for fields whose declaration site is [definition].
  // TODO(ahe): It would be nice if [computeDifference] returned this
  // information directly.
  void addFields(
      PartialFieldList definition,
      ScopeContainerElement container,
      ScopeContainerElement syntheticContainer) {
    List<FieldElementX> fields = <FieldElementX>[];
    syntheticContainer.forEachLocalMember((ElementX member) {
      if (member.declarationSite == definition) {
        fields.add(member);
      }
    });
    for (FieldElementX field in fields) {
      // TODO(ahe): This only works when there's one field per
      // PartialFieldList.
      addField(field, container);
    }
  }

  void addField(FieldElementX element, ScopeContainerElement container) {
    logVerbose("Add field $element to $container.");
    invalidateScopesAffectedBy(element, container);
    addAddedFieldUpdate(compiler, element, container);
  }

  bool canReuseRemovedElement(
      PartialElement element,
      ScopeContainerElement container) {
    if (!allowRemovedElement(element)) return false;
    if (element is PartialFunctionElement) {
      removeFunction(element);
      return true;
    } else if (element is PartialClassElement) {
      removeClass(element);
      return true;
    } else if (element is PartialFieldList) {
      removeFields(element, container);
      return true;
    }
    return cannotReuse(
        element, "Removing ${element.runtimeType} not supported.");
  }

  void removeFunction(PartialFunctionElement element) {
    logVerbose("Removed method $element.");

    invalidateScopesAffectedBy(element, element.enclosingElement);

    _removedElements.add(element);

    addRemovedFunctionUpdate(compiler, element);
  }

  void removeClass(PartialClassElement element) {
    logVerbose("Removed class $element.");

    invalidateScopesAffectedBy(element, element.library);

    _removedElements.add(element);
    element.forEachLocalMember((ElementX member) {
      _removedElements.add(member);
    });

    addRemovedClassUpdate(compiler, element);
  }

  void removeFields(
      PartialFieldList definition,
      ScopeContainerElement container) {
    List<FieldElementX> fields = <FieldElementX>[];
    container.forEachLocalMember((ElementX member) {
      if (member.declarationSite == definition) {
        fields.add(member);
      }
    });
    for (FieldElementX field in fields) {
      // TODO(ahe): This only works when there's one field per
      // PartialFieldList.
      removeField(field);
    }
  }

  void removeField(FieldElementX element) {
    logVerbose("Removed field $element.");
    if (!element.isInstanceMember) {
      cannotReuse(element, "Not an instance field.");
    } else {
      removeInstanceField(element);
    }
  }

  void removeInstanceField(FieldElementX element) {
    PartialClassElement cls = element.enclosingClass;

    invalidateScopesAffectedBy(element, cls);

    _removedElements.add(element);

    addRemovedFieldUpdate(compiler, element);
  }

  /// Returns true if [element] has generic types (or if we cannot rule out
  /// that it has generic types).
  bool checkForGenericTypes(Element element) {
    if (element is TypeDeclarationElement) {
      if (!element.isResolved) {
        if (element is PartialClassElement) {
          ClassNode node = element.parseNode(compiler.parsing).asClassNode();
          if (node == null) {
            cannotReuse(
                element, "Class body isn't a ClassNode on $element");
            return true;
          }
          bool isGeneric =
              node.typeParameters != null && !node.typeParameters.isEmpty;
          if (isGeneric) {
            // TODO(ahe): Support generic types.
            cannotReuse(
                element,
                "Type variables not supported: '${node.typeParameters}'");
            return true;
          }
        } else {
          cannotReuse(
              element, "Can't check for generic types on $element");
          return true;
        }
      } else if (!element.thisType.isRaw) {
        cannotReuse(
            element, "Generic types not supported: '${element.thisType}'");
        return true;
      }
    }
    return false;
  }

  void invalidateScopesAffectedBy(
      ElementX element,
      /* ScopeContainerElement */ container) {
    if (checkForGenericTypes(element)) return;
    for (ScopeContainerElement scope in scopesAffectedBy(element, container)) {
      scanSites(scope, (Element member, DeclarationSite site) {
        // TODO(ahe): Cache qualifiedNamesIn to avoid quadratic behavior.
        Set<String> names = qualifiedNamesIn(site);
        if (canNamesResolveStaticallyTo(names, element, container)) {
          if (checkForGenericTypes(member)) return;
          if (member is TypeDeclarationElement) {
            if (!member.isResolved) {
              // TODO(ahe): This is a bug in dart2js' forgetElement which
              // attempts to check if member is a generic type.
              cannotReuse(member, "Not resolved");
              return;
            }
          }
          _elementsToInvalidate.add(member);
        }
      });
    }
  }

  void replaceFunctionInBackend(
      ElementX element,
      /* ScopeContainerElement */ container) {
    List<Element> elements = <Element>[];
    if (checkForGenericTypes(element)) return;
    for (ScopeContainerElement scope in scopesAffectedBy(element, container)) {
      scanSites(scope, (Element member, DeclarationSite site) {
        // TODO(ahe): Cache qualifiedNamesIn to avoid quadratic behavior.
        Set<String> names = qualifiedNamesIn(site);
        if (canNamesResolveStaticallyTo(names, element, container)) {
          if (checkForGenericTypes(member)) return;
          if (member is TypeDeclarationElement) {
            if (!member.isResolved) {
              // TODO(ahe): This is a bug in dart2js' forgetElement which
              // attempts to check if member is a generic type.
              cannotReuse(member, "Not resolved");
              return;
            }
          }
          elements.add(member);
        }
      });
    }
    backend.replaceFunctionUsageElement(element, elements);
  }

  /// Invoke [f] on each [DeclarationSite] in [element]. If [element] is a
  /// [ScopeContainerElement], invoke f on all local members as well.
  void scanSites(
      Element element,
      void f(ElementX element, DeclarationSite site)) {
    DeclarationSite site = declarationSite(element);
    if (site != null) {
      f(element, site);
    }
    if (element is ScopeContainerElement) {
      element.forEachLocalMember((member) { scanSites(member, f); });
    }
  }

  /// Assume [element] is either removed from or added to [container], and
  /// return all [ScopeContainerElement] that can see this change.
  List<ScopeContainerElement> scopesAffectedBy(
      Element element,
      /* ScopeContainerElement */ container) {
    // TODO(ahe): Use library export graph to compute this.
    // TODO(ahe): Should return all user-defined libraries and packages.
    LibraryElement library = container.library;
    List<ScopeContainerElement> result = <ScopeContainerElement>[library];

    if (!container.isClass) return result;

    ClassElement cls = container;

    if (!cls.declaration.isResolved) {
      // TODO(ahe): This test fails otherwise: experimental/add_static_field.
      throw new IncrementalCompilationFailed(
          "Unresolved class ${cls.declaration}");
    }
    var externalSubtypes =
        compiler.world.subclassesOf(cls).where((e) => e.library != library);

    return result..addAll(externalSubtypes);
  }

  /// Returns true if function [before] can be reused to reflect the changes in
  /// [after].
  ///
  /// If [before] can be reused, an update (patch) is added to [updates].
  bool canReuseFunction(
      Token diffToken,
      PartialFunctionElement before,
      PartialFunctionElement after) {
    FunctionExpression node =
        after.parseNode(compiler.parsing).asFunctionExpression();
    if (node == null) {
      return cannotReuse(after, "Not a function expression: '$node'");
    }
    Token last = after.endToken;
    if (node.body != null) {
      last = node.body.getBeginToken();
    }
    if (before.isMalformed ||
        compiler.elementHasCompileTimeError(before) ||
        isTokenBetween(diffToken, after.beginToken, last)) {
      removeFunction(before);
      addFunction(after, before.enclosingElement);
      if (compiler.mainFunction == before) {
        return cannotReuse(
            after,
            "Unable to handle when signature of '${after.name}' changes");
      }
      return allowSignatureChanged(before, after);
    }
    logVerbose('Simple modification of ${after} detected');
    if (!before.isInstanceMember) {
      if (!allowNonInstanceMemberModified(after)) return false;
    }
    updates.add(new FunctionUpdate(compiler, before, after));
    return true;
  }

  bool canReuseClass(
      Token diffToken,
      PartialClassElement before,
      PartialClassElement after) {
    ClassNode node = after.parseNode(compiler.parsing).asClassNode();
    if (node == null) {
      return cannotReuse(after, "Not a ClassNode: '$node'");
    }
    NodeList body = node.body;
    if (body == null) {
      return cannotReuse(after, "Class has no body.");
    }
    if (isTokenBetween(diffToken, node.beginToken, body.beginToken.next)) {
      if (!allowClassHeaderModified(after)) return false;
      logVerbose('Class header modified in ${after}');
      addClassUpdate(compiler, before, after);
      before.forEachLocalMember((ElementX member) {
        // TODO(ahe): Quadratic.
        invalidateScopesAffectedBy(member, before);
      });
    } else {
      logVerbose('Simple modification of ${after} detected');
    }
    return canReuseScopeContainerElement(before, after);
  }

  /// Returns true if [token] is found between [first] (included) and [last]
  /// (excluded).
  bool isTokenBetween(Token token, Token first, Token last) {
    Token current = first;
    while (current != last && current.kind != EOF_TOKEN) {
      if (current == token) {
        return true;
      }
      current = current.next;
    }
    return false;
  }

  bool unableToReuse(
      Token diffToken,
      PartialElement before,
      PartialElement after) {
    return cannotReuse(
        after,
        'Unhandled change:'
        ' ${before} (${before.runtimeType} -> ${after.runtimeType}).');
  }

  /// Apply the collected [updates]. Return a list of elements that needs to be
  /// recompiled after applying the updates.
  List<Element> applyUpdates() {
    for (Update update in updates) {
      update.captureState();
    }
    if (_failedUpdates.isNotEmpty) {
      throw new IncrementalCompilationFailed(_failedUpdates.join('\n\n'));
    }
    for (ElementX element in _elementsToInvalidate) {
      compiler.forgetElement(element);
      element.reuseElement();
      if (element.isFunction) {
        replaceFunctionInBackend(element, element.enclosingElement);
      }
    }
    List<Element> elementsToInvalidate = <Element>[];
    for (ElementX element in _elementsToInvalidate) {
      if (!_removedElements.contains(element)) {
        elementsToInvalidate.add(element);
      }
    }
    for (Update update in updates) {
      Element element = update.apply(backend);
      if (!update.isRemoval) {
        elementsToInvalidate.add(element);
      }
      if (update is FunctionUpdate) {
        replaceFunctionInBackend(element, element.enclosingElement);
      }
    }
    return elementsToInvalidate;
  }

  void addClassUpdate(
      Compiler compiler,
      PartialClassElement before,
      PartialClassElement after);

  void addAddedFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement element,
      /* ScopeContainerElement */ container);

  void addRemovedFunctionUpdate(
      Compiler compiler,
      PartialFunctionElement element);

  void addRemovedFieldUpdate(
      Compiler compiler,
      FieldElementX element);

  void addRemovedClassUpdate(
      Compiler compiler,
      PartialClassElement element);

  void addAddedFieldUpdate(
      Compiler compiler,
      FieldElementX element,
      /* ScopeContainerElement */ container);

  void addAddedClassUpdate(
      Compiler compiler,
      PartialClassElement element,
      LibraryElementX library);

  bool uriHasUpdate(Uri uri);

  bool allowClassHeaderModified(PartialClassElement after);

  bool allowSignatureChanged(
      PartialFunctionElement before,
      PartialFunctionElement after);

  bool allowNonInstanceMemberModified(PartialFunctionElement after);

  bool allowRemovedElement(PartialElement element);

  bool allowAddedElement(PartialElement element);
}

/// Represents an update (aka patch) of [before] to [after]. We use the word
/// "update" to avoid confusion with the compiler feature of "patch" methods.
abstract class Update {
  final Compiler compiler;

  PartialElement get before;

  PartialElement get after;

  Update(this.compiler);

  /// Applies the update to [before] and returns that element.
  Element apply(IncrementalBackend backend);

  bool get isRemoval => false;

  /// Called before any patches are applied to capture any state that is needed
  /// later.
  void captureState() {
  }
}

/// Represents an update of a function element.
class FunctionUpdate extends Update with ReuseFunctionElement {
  final PartialFunctionElement before;

  final PartialFunctionElement after;

  FunctionUpdate(Compiler compiler, this.before, this.after)
      : super(compiler);

  PartialFunctionElement apply(IncrementalBackend backend) {
    patchElement();
    reuseElement();
    return before;
  }

  /// Destructively change the tokens in [before] to match those of [after].
  void patchElement() {
    before.beginToken = after.beginToken;
    before.endToken = after.endToken;
    before.getOrSet = after.getOrSet;
  }
}

abstract class ReuseFunctionElement {
  Compiler get compiler;

  PartialFunctionElement get before;

  /// Reset various caches and remove this element from the compiler's internal
  /// state.
  void reuseElement() {
    compiler.forgetElement(before);
    before.reuseElement();
  }
}

abstract class RemovalUpdate extends Update {
  ElementX get element;

  RemovalUpdate(Compiler compiler)
      : super(compiler);

  bool get isRemoval => true;

  void removeFromEnclosing() {
    // TODO(ahe): Need to recompute duplicated elements logic again. Simplest
    // solution is probably to remove all elements from enclosing scope and add
    // them back.
    if (element.isTopLevel) {
      removeFromLibrary(element.library);
    } else {
      removeFromEnclosingClass(element.enclosingClass);
    }
  }

  void removeFromEnclosingClass(PartialClassElement cls) {
    cls.localMembersCache = null;
    cls.localMembersReversed = cls.localMembersReversed.copyWithout(element);
    cls.localScope.contents.remove(element.name);
  }

  void removeFromLibrary(LibraryElementX library) {
    library.localMembers = library.localMembers.copyWithout(element);
    library.localScope.contents.remove(element.name);
  }
}

abstract class RemovedFunctionUpdate extends RemovalUpdate
    with ReuseFunctionElement {
  final PartialFunctionElement element;

  bool wasStateCaptured = false;

  RemovedFunctionUpdate(Compiler compiler, this.element)
      : super(compiler);

  PartialFunctionElement get before => element;

  PartialFunctionElement get after => null;

  void captureState() {
    if (wasStateCaptured) throw "captureState was called twice.";
    wasStateCaptured = true;
  }

  PartialFunctionElement apply(IncrementalBackend backend) {
    if (!wasStateCaptured) throw "captureState must be called before apply.";
    removeFromEnclosing();
    backend.removeFunction(element);
    reuseElement();
    return null;
  }
}

abstract class RemovedClassUpdate extends RemovalUpdate {
  final PartialClassElement element;

  bool wasStateCaptured = false;

  RemovedClassUpdate(Compiler compiler, this.element)
      : super(compiler);

  PartialClassElement get before => element;

  PartialClassElement get after => null;

  void captureState() {
    if (wasStateCaptured) throw "captureState was called twice.";
    wasStateCaptured = true;
  }

  PartialClassElement apply(IncrementalBackend backend) {
    if (!wasStateCaptured) {
      throw new StateError("captureState must be called before apply.");
    }

    removeFromEnclosing();

    element.forEachLocalMember((ElementX member) {
      compiler.forgetElement(member);
      member.reuseElement();
    });

    compiler.forgetElement(element);
    element.reuseElement();

    return null;
  }
}

abstract class RemovedFieldUpdate extends RemovalUpdate {
  final FieldElementX element;

  bool wasStateCaptured = false;

  RemovedFieldUpdate(Compiler compiler, this.element)
      : super(compiler);

  PartialFieldList get before => element.declarationSite;

  PartialFieldList get after => null;

  void captureState() {
    if (wasStateCaptured) throw "captureState was called twice.";
    wasStateCaptured = true;
  }

  FieldElementX apply(IncrementalBackend backend) {
    if (!wasStateCaptured) {
      throw new StateError("captureState must be called before apply.");
    }
    removeFromEnclosing();
    return element;
  }
}

abstract class AddedFunctionUpdate extends Update {
  final PartialFunctionElement element;

  final /* ScopeContainerElement */ container;

  AddedFunctionUpdate(Compiler compiler, this.element, this.container)
      : super(compiler) {
    if (container == null) {
      throw "container is null";
    }
  }

  PartialFunctionElement get before => null;

  PartialFunctionElement get after => element;

  PartialFunctionElement apply(IncrementalBackend backend) {
    Element enclosing = container;
    if (enclosing.isLibrary) {
      // TODO(ahe): Reuse compilation unit of element instead?
      enclosing = enclosing.compilationUnit;
    }
    PartialFunctionElement copy = element.copyWithEnclosing(enclosing);
    container.addMember(copy, compiler.reporter);
    return copy;
  }
}

abstract class AddedClassUpdate extends Update {
  final PartialClassElement element;

  final LibraryElementX library;

  AddedClassUpdate(Compiler compiler, this.element, this.library)
      : super(compiler);

  PartialClassElement get before => null;

  PartialClassElement get after => element;

  PartialClassElement apply(IncrementalBackend backend) {
    // TODO(ahe): Reuse compilation unit of element instead?
    CompilationUnitElementX compilationUnit = library.compilationUnit;
    PartialClassElement copy = element.copyWithEnclosing(compilationUnit);
    compilationUnit.addMember(copy, compiler.reporter);
    return copy;
  }
}

abstract class AddedFieldUpdate extends Update {
  final FieldElementX element;

  final /* ScopeContainerElement */ container;

  AddedFieldUpdate(Compiler compiler, this.element, this.container)
      : super(compiler);

  PartialFieldList get before => null;

  PartialFieldList get after => element.declarationSite;

  FieldElementX apply(IncrementalBackend backend) {
    Element enclosing = container;
    if (enclosing.isLibrary) {
      // TODO(ahe): Reuse compilation unit of element instead?
      enclosing = enclosing.compilationUnit;
    }
    FieldElementX copy = element.copyWithEnclosing(enclosing);
    container.addMember(copy, compiler.reporter);
    return copy;
  }
}

abstract class ClassUpdate extends Update {
  final PartialClassElement before;

  final PartialClassElement after;

  ClassUpdate(Compiler compiler, this.before, this.after)
      : super(compiler);

  PartialClassElement apply(IncrementalBackend backend) {
    patchElement();
    reuseElement();
    return before;
  }

  /// Destructively change the tokens in [before] to match those of [after].
  void patchElement() {
    before.cachedNode = after.cachedNode;
    before.beginToken = after.beginToken;
    before.endToken = after.endToken;
  }

  void reuseElement() {
    before.supertype = null;
    before.interfaces = null;
    before.supertypeLoadState = STATE_NOT_STARTED;
    before.resolutionState = STATE_NOT_STARTED;
    before.isProxy = false;
    before.hasIncompleteHierarchy = false;
    before.backendMembers = const Link<Element>();
    before.allSupertypesAndSelf = null;
  }
}

/// Returns all qualified names in [element] with less than four identifiers. A
/// qualified name is an identifier followed by a sequence of dots and
/// identifiers, for example, "x", and "x.y.z". But not "x.y.z.w" ("w" is the
/// fourth identifier).
///
/// The longest possible name that can be resolved is three identifiers, for
/// example, "prefix.MyClass.staticMethod". Since four or more identifiers
/// cannot resolve to anything statically, they're not included in the returned
/// value of this method.
Set<String> qualifiedNamesIn(PartialElement element) {
  Token beginToken = element.beginToken;
  Token endToken = element.endToken;
  Token token = beginToken;
  if (element is PartialClassElement) {
    ClassNode node = element.cachedNode;
    if (node != null) {
      NodeList body = node.body;
      if (body != null) {
        endToken = body.beginToken;
      }
    }
  }
  Set<String> names = new Set<String>();
  do {
    if (token.isIdentifier()) {
      String name = token.value;
      // [name] is a single "identifier".
      names.add(name);
      if (identical('.', token.next.stringValue) &&
          token.next.next.isIdentifier()) {
        token = token.next.next;
        name += '.${token.value}';
        // [name] is "idenfifier.idenfifier".
        names.add(name);

        if (identical('.', token.next.stringValue) &&
            token.next.next.isIdentifier()) {
          token = token.next.next;
          name += '.${token.value}';
          // [name] is "idenfifier.idenfifier.idenfifier".
          names.add(name);

          while (identical('.', token.next.stringValue) &&
                 token.next.next.isIdentifier()) {
            // Skip remaining identifiers, they cannot statically resolve to
            // anything, and must be dynamic sends.
            token = token.next.next;
          }
        }
      }
    }
    token = token.next;
  } while (token.kind != EOF_TOKEN && token != endToken);
  return names;
}

/// Returns true if one of the qualified names in names (as computed by
/// [qualifiedNamesIn]) could be a static reference to [element].
bool canNamesResolveStaticallyTo(
    Set<String> names,
    Element element,
    /* ScopeContainerElement */ container) {
  if (names.contains(element.name)) return true;
  if (container != null && container.isClass) {
    // [names] contains C.m, where C is the name of [container], and m is the
    // name of [element].
    if (names.contains("${container.name}.${element.name}")) return true;
  }
  // TODO(ahe): Check for prefixes as well.
  return false;
}

DeclarationSite declarationSite(Element element) {
  return element is ElementX ? element.declarationSite : null;
}
