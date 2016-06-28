// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// A wrapper around dart doc that specializes it to generate docs for the
/// dartino sdk and packages.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import 'package:dartdoc/dartdoc.dart';
import 'package:dartdoc/src/config.dart';
import 'package:dartdoc/src/package_meta.dart';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/analyzer.dart';

import 'package:compiler/src/platform_configuration.dart';

import 'package:dartdoc/src/generator.dart';
import 'package:dartdoc/src/html/html_generator.dart';

class DartinoSdk extends DartSdk {
  final Map<String, Uri> mapping;
  final Map<String, Source> cache = new Map<String, Source>();
  final String sdkVersion;

  DartinoSdk(this.mapping, this.sdkVersion);

  AnalysisContext context;

  List<SdkLibrary> get sdkLibraries {
    throw "sdkLibraries";
  }

  List<String> get uris => mapping.keys.map((x) => "dart:$x").toList();

  Source fromFileUri(Uri uri) => mapDartUri(uri.toFilePath());

  SdkLibrary getSdkLibrary(String uri) => throw "getSdkLibrary";

  Source mapDartUri(String uri) {
    return cache.putIfAbsent(uri, () {
      Uri fileUri = mapping[uri];
      if (fileUri.scheme == "undefined") return null;
      return new FileBasedSource(new JavaFile(fileUri.toFilePath()));
    });
  }
}

class DartinoDartUriResolver extends UriResolver implements DartUriResolver {
  final DartSdk dartSdk;

  DartinoDartUriResolver(this.dartSdk);

  @override
  Source resolveAbsolute(Uri uri, [Uri actualUri]) {
    if (uri.scheme == "dart") {
      var x = dartSdk.mapDartUri(uri.path);
      return x;
    } else {
      return null;
    }
  }
}

/// A library with a custom name.
///
/// Delegates everything except name and isInSdk to another LibraryElement.
class CustomNamedLibraryElement implements LibraryElement {
  final String name;
  final bool isInSdk;
  final LibraryElement _element;

  CustomNamedLibraryElement(this._element, this.name, this.isInSdk);

  AnalysisContext get context => _element.context;
  String get displayName => name;
  @deprecated
  SourceRange get docRange => _element.docRange;
  String get documentationComment => _element.documentationComment;
  Element get enclosingElement => _element.enclosingElement;
  int get id => _element.id;
  bool get isDeprecated => _element.isDeprecated;
  bool get isOverride => _element.isOverride;
  bool get isPrivate => _element.isPrivate;
  bool get isProtected => _element.isProtected;
  bool get isPublic => _element.isPublic;
  bool get isSynthetic => _element.isSynthetic;
  ElementKind get kind => _element.kind;
  LibraryElement get library => this;
  ElementLocation get location => _element.location;
  List<ElementAnnotation> get metadata => _element.metadata;
  int get nameLength => _element.nameLength;
  int get nameOffset => _element.nameOffset;
  @override
  Source get source => _element.source;
  CompilationUnit get unit => _element.unit;
  accept(ElementVisitor visitor) => _element.accept(visitor);
  @deprecated
  String computeDocumentationComment() => _element.computeDocumentationComment();
  AstNode computeNode() => _element.computeNode();
  Element getAncestor(predicate) {
    return _element.getAncestor(predicate);
  }

  String getExtendedDisplayName(String shortName) {
    return _element.getExtendedDisplayName(shortName);
  }

  bool isAccessibleIn(LibraryElement library) {
    return _element.isAccessibleIn(library);
  }

  void visitChildren(ElementVisitor visitor) => _element.visitChildren(visitor);
  CompilationUnitElement get definingCompilationUnit {
    return _element.definingCompilationUnit;
  }

  FunctionElement get entryPoint => _element.entryPoint;
  List<LibraryElement> get exportedLibraries => _element.exportedLibraries;
  get exportNamespace => _element.exportNamespace;
  List<ExportElement> get exports => _element.exports;
  bool get hasExtUri => _element.hasExtUri;
  bool get hasLoadLibraryFunction => _element.hasLoadLibraryFunction;
  String get identifier => _element.identifier;
  List<LibraryElement> get importedLibraries => _element.importedLibraries;
  List<ImportElement> get imports => _element.imports;
  bool get isBrowserApplication => _element.isBrowserApplication;
  bool get isDartAsync => _element.isDartAsync;
  bool get isDartCore => _element.isDartCore;
  List<LibraryElement> get libraryCycle => _element.libraryCycle;
  FunctionElement get loadLibraryFunction => _element.loadLibraryFunction;
  List<CompilationUnitElement> get parts => _element.parts;
  List<PrefixElement> get prefixes => _element.prefixes;
  get publicNamespace => _element.publicNamespace;
  List<CompilationUnitElement> get units => _element.units;
  List<LibraryElement> get visibleLibraries => _element.visibleLibraries;
  List<ImportElement> getImportsWithPrefix(PrefixElement prefix) {
    return _element.getImportsWithPrefix(prefix);
  }

  ClassElement getType(String className) => _element.getType(className);
  bool isUpToDate(int timeStamp) => _element.isUpToDate(timeStamp);
}

class DartinoPackage {
  String name;
  Directory dir;
  DartinoPackage(this.name, this.dir);
}

class Library {
  String package;
  String path;
  bool isSdk;
  String relativePath;
  Library(this.path, this.package, this.isSdk, this.relativePath);
}

List<LibraryElement> parseLibraries(
    List<Library> libraries, DartinoSdk dartinoSdk) {
  List<LibraryElement> libraryElements = [];

  List<UriResolver> resolvers = new List<UriResolver>();
  DartUriResolver sdkResolver = new DartinoDartUriResolver(dartinoSdk);
  resolvers.add(sdkResolver);
  resolvers.add(new FileUriResolver());

  SourceFactory sourceFactory = new SourceFactory(resolvers);

  AnalysisEngine.instance.processRequiredPlugins();

  AnalysisContext context = AnalysisEngine.instance.createAnalysisContext();
  dartinoSdk.context = context;
  context.sourceFactory = sourceFactory;

  List<Source> sources = new List<Source>();

  void processLibrary(Library library) {
    String filePath = library.path;
    print('Dartinodoc parsing ${filePath}...');
    JavaFile javaFile = new JavaFile(filePath).getAbsoluteFile();
    Source source = new FileBasedSource(javaFile);
    Uri uri = context.sourceFactory.restoreUri(source);
    if (uri != null) {
      source = new FileBasedSource(javaFile, uri);
    }
    sources.add(source);
    if (context.computeKindOf(source) == SourceKind.LIBRARY) {
      LibraryElement libraryElement = context.computeLibraryElement(source);

      // Sort out internal libraries from the SDK
      if (libraryElement.name.split(".").last.startsWith("_")) return;

      String name = library.isSdk
          ? "dart:${libraryElement.name.substring(5)}"
          : libraryElement.name;
      libraryElements.add(
          new CustomNamedLibraryElement(libraryElement, name, library.isSdk));
    }
  }

  libraries.forEach(processLibrary);
  libraryElements.removeWhere(
      (LibraryElement library) => library.name.split(".").last.startsWith("_"));
  return libraryElements;
}

class DartinoPackageMeta extends PackageMeta {
  final String version;

  DartinoPackageMeta(Directory dir, this.version) : super(dir);

  bool get isSdk => true;

  String get name => "Dartino libraries";

  // TODO(sigurdm): What is this?
  String get description => "";

  String get homepage => "https://dartino.org/";

  FileContents getReadmeContents() => null;
  FileContents getLicenseContents() => null;
  FileContents getChangelogContents() => null;

  /// Returns true if we are a valid package, valid enough to generate docs.
  bool get isValid => true;

  /// Returns a list of reasons this package is invalid, or an
  /// empty list if no reasons found.
  ///
  /// If the list is empty, this package is valid.
  List<String> getInvalidReasons() => [];

  String toString() => name;
}

ArgParser createArgParser() {
  var parser = new ArgParser();
  parser.addFlag('help',
      abbr: 'h', negatable: false, help: 'Show command help.');
  parser.addOption('output',
      help: 'Path to output directory.', defaultsTo: defaultOutDir);
  parser.addOption('sdk-packages',
      help: 'comma-separated list of package-names from pkg/', defaultsTo: "");
  parser.addOption('third-party-packages',
      help: 'comma-separated list of package-names from third-party/',
      defaultsTo: "");
  parser.addOption('hosted-url',
      help:
          'URL where the docs will be hosted (used to generate the sitemap).');
  parser.addOption('platform-file',
      help: 'platform file describing the sdk.',
      defaultsTo: 'lib/dartino_embedded.platform');
  parser.addOption('favicon',
      help: 'A path to a favicon for the generated docs');
  parser.addOption('version',
      help: 'The version of the dartino sdk being documented');
  return parser;
}

void printUsageAndExit(ArgParser parser, {int exitCode: 0}) {
  print('Usage: dartinodoc [OPTIONS]\n');
  print(parser.usage);
  exit(exitCode);
}

Future<Null> main(List<String> arguments) async {
  ArgParser argParser = createArgParser();
  ArgResults args;
  try {
    args = argParser.parse(arguments);
  } on FormatException catch (e) {
    print(e.message);
    print('');
    printUsageAndExit(argParser, exitCode: 64);
  }

  String hostedUrl = args['hosted-url'];
  List<String> headerFilePaths = [];
  List<String> footerFilePaths = [];

  Uri platformUri = Uri.parse(args['platform-file']);
  List<int> platform = await new File.fromUri(platformUri).readAsBytes();
  Map<String, Uri> sdkMappings =
      libraryMappings(parseIni(platform), platformUri);

  Iterable<Library> sdkLibraries =
      sdkMappings.values.where((Uri x) => x.scheme != "unsupported").map((x) {
    return new Library(x.toFilePath(), null, true, null);
  });

  String outputPath = arguments.length > 0 ? arguments[0] : './dartinodoc';

  Directory outputDir = new Directory(outputPath);

  initializeConfig(
      inputDir: null,
      sdkVersion: args['version'],
      addCrossdart: false,
      includeSource: false);

  List<Library> findExportedLibraries(DartinoPackage package, [Directory dir]) {
    bool top = dir == null;
    if (top) {
      dir = package.dir;
    }
    List<Library> result = new List<Library>();
    for (FileSystemEntity entity in dir.listSync()) {
      if (entity is File) {
        String path = entity.path;
        if (path.endsWith(".dart")) {
          String relativePath = path.substring(package.dir.path.length + 1);
          result.add(new Library(path, package.name, false, relativePath));
        }
      } else if (entity is Directory) {
        if (top && entity.path.endsWith("/src")) continue;
        result.addAll(findExportedLibraries(package, entity));
      }
    }
    return result;
  }

  Iterable<DartinoPackage> sdkPackages = args['sdk-packages'].split(",").map(
      (String name) =>
          new DartinoPackage(name, new Directory("pkg/$name/lib")));
  Iterable<DartinoPackage> thirdPartyPackages = args['third-party-packages']
      .split(",")
      .map((String name) =>
          new DartinoPackage(name, new Directory("third_party/$name/lib")));

  Iterable<DartinoPackage> packages =
      [sdkPackages, thirdPartyPackages].expand((x) => x);

  Iterable<Library> packageLibraries = packages
      .expand((DartinoPackage package) => findExportedLibraries(package));

  List<LibraryElement> libraries = parseLibraries(
      [sdkLibraries, packageLibraries].expand((x) => x).toList(),
      new DartinoSdk(sdkMappings, args['version']));

  Package package = new Package(
      libraries, new DartinoPackageMeta(new Directory("."), args['version']));

  // Create the out directory.
  if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

  Generator generator = await HtmlGenerator.create(
      url: hostedUrl,
      headers: headerFilePaths,
      footers: footerFilePaths,
      relCanonicalPrefix: null,
      toolVersion: "",
      faviconPath: null,
      useCategories: true);
  await generator.generate(package, outputDir);
}
