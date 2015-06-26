// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'json.dart';

class Resource {
  String host;
  String path;
  Resource(this.host, this.path);
  Resource sub(subpath) => new Resource(host, "$path$subpath");
}

class Project {
  String name;
  Console console;
  Project(this.name);
}

abstract class RemoteData {
  var data = null;

  bool _wait = true;
  var _channel = new Channel();

  void updateData([onComplete = null]) {
    Fiber.fork(() {
      this._run();
      if (onComplete != null)
        onComplete();
    });
  }

  void ensureData() {
    if (_wait) {
      _channel.receive();
      _wait = false;
    }
  }

  dynamic fetchData();

  void _run() {
    data = fetchData();
    if (_wait) _channel.send(null);
  }
}

class JsonData extends RemoteData {
  Resource resource;
  JsonData(this.resource);
  dynamic fetchData() => getJson(resource.host, resource.path);
}

class Console {
  String title;

  JsonData _jsonStatus;
  JsonData _jsonChanges;

  String _status = "unknown status";
  List<String> _commitKeys = new List();

  Console(this.title,
          Resource api,
          Resource status) {
    _jsonStatus = new JsonData(status.sub("/current?format=json"));
    _jsonStatus.updateData(updateStatus);

    _jsonChanges = new JsonData(api.sub("/json/changes"));
    _jsonChanges.updateData(updateCommits);
  }

  String get status => _status;

  int get commitCount => _commitKeys.length > 0 ? 10000 : 0;

  dynamic commit(int index) {
    int length = _commitKeys.length;
    if (length == 0) return null;
    return _jsonChanges.data[_commitKeys[index % length]];
  }

  void updateCommits() {
    var data = _jsonChanges.data;
    _commitKeys = data.keys.toList();
    _commitKeys.sort();
    // TODO(zerny): queue up another update (but don't pressure the bots).
  }

  void updateStatus() {
    _status = _jsonStatus.data['message'];
    // TODO(zerny): queue up another update (but don't pressure the bots).
  }
}
