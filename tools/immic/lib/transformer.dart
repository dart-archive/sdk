// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.transformer;

import 'dart:async';
import 'package:barback/barback.dart';

import 'src/parser.dart';
import 'src/resolver.dart';
import 'src/importer.dart';

import 'src/plugins/dart.dart' as dart;
import 'package:path/path.dart' as p;

class ImportResolverWithTransform implements ImportResolver<AssetId> {
  final Transform transform;
  final Set<AssetId> visited = new Set();

  ImportResolverWithTransform(this.transform);

  Future<String> read(AssetId asset) async {
    return transform.readInputAsString(asset);
  }

  AssetId resolve(Import import, AssetId context) {
    String package;
    String path;
    if (import.package == null) {
      package = context.package;
      path = p.normalize(p.join(p.dirname(context.path), import.path));
    } else {
      package = import.package;
      path = p.join('lib', import.path);
    }
    AssetId id = new AssetId(package, path);
    if (visited.contains(id)) {
      return null;
    }
    visited.add(id);
    return id;
  }
}

class ImmiNodeTransformer extends Transformer {
  String _root;
  ImmiNodeTransformer.asPlugin(BarbackSettings settings) {
    _root = settings.configuration['root'];
  }

  String get allowedExtensions => '.immi';

  Future apply(Transform transform) async {
    var content = await transform.primaryInput.readAsString();
    var asset = transform.primaryInput;
    var id = asset.id.changeExtension('_immi.dart');
    var path = asset.id.path;

    Unit topUnit = parseUnit(content);
    AssetId context = asset.id;
    Map<String, Unit> units = await parseImports(
        topUnit, new ImportResolverWithTransform(transform), context);

    resolve(units);
    String newContent = dart.generateNodeString(path, topUnit);
    transform.addOutput(new Asset.fromString(id, newContent));

    if (path == _root) {
      AssetId serviceFile = asset.id.changeExtension('_immi_service.dart');
      String serviceContent = dart.generateServiceString(path, units);
      transform.addOutput(new Asset.fromString(serviceFile, serviceContent));
    }
  }
}
