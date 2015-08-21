// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.cc;

import 'dart:core' hide Type;
import 'dart:io' show Platform, File;

import 'package:path/path.dart' show basenameWithoutExtension, join, dirname;

import 'shared.dart';

import '../emitter.dart';
import '../primitives.dart' as primitives;
import '../struct_layout.dart';

const List<String> RESOURCES = const [
  'AnyNodePresenter.java',
  'ImmiRoot.java',
  'ImmiService.java',
  'Node.java',
  'NodePatch.java',
  'NodePresenter.java',
  'Patch.java',
];

void generate(String path, Map units, String outputDirectory) {
  String directory = join(outputDirectory, 'java', 'immi');
  _generateNodeFiles(path, units, directory);

  String resourcesDirectory = join(dirname(Platform.script.path),
      '..', 'lib', 'src', 'resources', 'java');
  for (String resource in RESOURCES) {
    String resourcePath = join(resourcesDirectory, resource);
    File file = new File(resourcePath);
    String contents = file.readAsStringSync();
    writeToFile(directory, resource, contents);
  }
}

void _generateNodeFiles(String path, Map units, String outputDirectory) {
  new _AnyNodeWriter(units).writeTo(outputDirectory);
  new _AnyNodePatchWriter(units).writeTo(outputDirectory);
}

class _JavaVisitor extends CodeGenerationVisitor {
  static const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

  _JavaVisitor(String path) : super(path);
}

class _JavaWriter extends _JavaVisitor {
  final String name;

  _JavaWriter(String name)
      : super(name),
        name = name;

  void writeHeader([List<String> imports = const []]) {
    writeln(_JavaVisitor.COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
    writeln('package immi;');
    writeln();
    imports.forEach((import) { writeln('import $import;'); });
    if (imports.isNotEmpty) writeln();
  }

  void writeTo(String directory) {
    writeToFile(directory, name, buffer.toString(), extension: 'java');
  }
}

class _AnyNodeWriter extends _JavaWriter {
  _AnyNodeWriter(Map units)
      : super('AnyNode') {
    writeHeader();
    writeln('public final class $name implements Node {}');
  }
}

class _AnyNodePatchWriter extends _JavaWriter {
  _AnyNodePatchWriter(Map units)
      : super('AnyNodePatch') {
    writeHeader([
      'fletch.NodePatchData'
    ]);
    write('public final class $name');
    writeln(' implements NodePatch<AnyNode, AnyNodePresenter> {');
    writeln('  public AnyNode getCurrent() { return null; }');
    writeln('  public AnyNode getPrevious() { return null; }');
    writeln('  public void applyTo(AnyNodePresenter presenter) { }');
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeln('  $name(NodePatchData data, Node previous, ImmiRoot root) {');
    writeln('    this.previous = (previous instanceof AnyNode) ?');
    writeln('        (AnyNode)previous : null;');
    writeln('  }');
    writeln();
    writeln('  private AnyNode current;');
    writeln('  private AnyNode previous;');
    writeln('}');
  }
}
