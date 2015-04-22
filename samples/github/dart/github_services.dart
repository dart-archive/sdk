// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'json.dart';

class Server {
  static const githubApiUrl = 'https://api.github.com';
  final String host;
  final int port;

  Server(this.host, this.port);

  dynamic get(String resource) => getJson(host, port, resource);

  User getUser(String name) => new User(name, this);
}

abstract class Service {
  final String api;
  final Server server;

  var _data = null;

  Service(this.api, this.server);

  dynamic operator[](String key) {
    _ensureData();
    return _data[key];
  }

  void _ensureData() {
    if (_data != null) return;
    _data = server.get(api);
  }
}

class User extends Service {
  final String name;

  User(String name, Server parent)
      : super('users/$name', parent),
        this.name = name;

  Repository getRepository(String repo) => new Repository(repo, this);
}

class Repository extends Service {
  final String name;

  Repository(String name, User parent)
      : super('repos/${parent.name}/$name', parent.server),
        this.name = name;
}
