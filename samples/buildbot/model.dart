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

  void updateData() {
    Thread.fork(() { this._run(); });
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

  JsonData _status;
  JsonData _changes;

  Console(this.title,
          Resource api,
          Resource status) {
    _status = new JsonData(status.sub("/current?format=json"));
    _status.updateData();
    _changes = new JsonData(api.sub("/json/changes"));
  }

  String get status {
    _status.ensureData();
    if (_status.data is Map && _status.data.containsKey("message")) {
      return _status.data['message'];
    }
    return "unknown status";
  }
}
