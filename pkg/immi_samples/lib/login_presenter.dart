// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:immi/dart/immi.dart';

 // Export generated code for nodes in login_presenter.immi
import 'package:immi/dart/login_presenter.dart';
export 'package:immi/dart/login_presenter.dart';

class LoginPresenter {
  static const String _emptyNameOrPassword =
    'Login failed. Empty name or password.';

  Node state;
  String url;
  String user;

  LoginPresenter(this.url) {
    state = new LoggedOutStateNode(login: login, message: '');
  }

  LoginNode present(Node prev) {
    return new LoginNode(state: state);
  }

  void login(String name, String password) {
    user = name;
    if (name == '' || password == '') {
      state = new LoggedOutStateNode(login: login,
                                     message: _emptyNameOrPassword);
    } else {
      HttpsRequestNode request =
	new HttpsRequestNode(url: url,
			     authorization: _createAuthToken(name, password),
			     handleResponse: _handleResponse);
      state = new LoginRequestStateNode(request: request);
    }
  }

  String _createAuthToken(String name, String password) {
     List<int> bytes = UTF8.encode('$name:$password');
     String base64 = CryptoUtils.bytesToBase64(bytes);
     return 'Basic $base64';
  }

  void _handleResponse(String data) {
    // TODO(zarah): implement this and return depending on data.
    state = new LoggedInStateNode(logout: logout, user: user);
  }

  void logout() {
    state = new LoggedOutStateNode(login: login, message: '');
  }
}
