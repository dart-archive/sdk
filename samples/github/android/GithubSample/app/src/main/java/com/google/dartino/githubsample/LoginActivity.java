// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.dartino.githubsample;

import android.app.Activity;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Base64;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URL;

import javax.net.ssl.HttpsURLConnection;

public class LoginActivity extends Activity {

  private static final String githubUrl = "https://api.github.com/user/repos";

  // TODO(zarah): use and update login state in graph instead.
  private boolean loggedIn = false;
  private EditText usernameView;
  private EditText passwordView;
  private Button loginoutButton;
  private TextView loginTitleView;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.login_layout);
    passwordView = (EditText) findViewById(R.id.password);
    usernameView = (EditText) findViewById(R.id.username);
    loginoutButton = (Button) findViewById(R.id.loginout_button);
    loginTitleView = (TextView) findViewById(R.id.login_title);
  }

  @Override
  public boolean onOptionsItemSelected(MenuItem item) {
    switch (item.getItemId()) {
      // Respond to the action bar's Up/Home button
      case android.R.id.home:
        finish();
        return true;
    }
    return super.onOptionsItemSelected(item);
  }

  public void toggleLogin(View view) {
    if (loggedIn) {
      logout();
    } else {
      requestLogin();
    }
  }

  private void requestLogin() {
    loginTitleView.setText(getString(R.string.login_request));
    loginoutButton.setVisibility(View.GONE);
    usernameView.setVisibility(View.GONE);
    passwordView.setVisibility(View.GONE);

    String username = usernameView.getText().toString();
    String password = passwordView.getText().toString();
    LoginTask loginTask = new LoginTask();
    loginTask.execute(new String[]{githubUrl, username, password});
  }

  private void logout() {
    loggedIn = false;
    usernameView.setVisibility(View.VISIBLE);
    passwordView.setVisibility(View.VISIBLE);
    loginTitleView.setText(getString(R.string.login_title));
    loginoutButton.setText(getString(R.string.login_button));
  }

  private void login(String token) {
    // TODO(zarah): use token to update commit lists.

    loggedIn = true;
    usernameView.setVisibility(View.GONE);
    passwordView.setVisibility(View.GONE);
    loginoutButton.setVisibility(View.VISIBLE);
    loginoutButton.setText(getString(R.string.logout_button));
    loginTitleView.setText(getString(R.string.login_success));
  }

  private void loginError() {
    // TODO(zarah): show more info on the type of error.

    Toast.makeText(LoginActivity.this, getString(R.string.login_error), Toast.LENGTH_LONG).show();
    loginTitleView.setText(getString(R.string.login_title));
    usernameView.setVisibility(View.VISIBLE);
    passwordView.setVisibility(View.VISIBLE);
    loginoutButton.setVisibility(View.VISIBLE);
  }

  private class LoginTask extends AsyncTask<String, Void, String> {

    @Override
    protected String doInBackground(String... params) {
      String urlString = params[0];
      String user = params[1];
      String password = params[2];

      byte[] loginBytes = (user + ":" + password).getBytes();
      StringBuilder loginBuilder = new StringBuilder()
          .append("Basic ")
          .append(Base64.encodeToString(loginBytes, Base64.DEFAULT));

      BufferedReader reader = null;
      try {
        URL url = new URL(urlString);
        HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
        connection.addRequestProperty("Authorization", loginBuilder.toString());
        connection.connect();

        StringBuilder result = new StringBuilder();
        reader = new BufferedReader(new InputStreamReader(connection.getInputStream()));
        String line;
        while ((line = reader.readLine()) != null) {
          result.append(line + "\n");
        }

        return result.toString();

      } catch (Exception e) {
        return null;
      } finally {
        if (reader != null) {
          try {
            reader.close();
          } catch (IOException e) {
            e.printStackTrace();
          }
        }
      }
    }

    @Override
    protected void onPostExecute(String token) {
      if (token == null) {
        loginError();
        return;
      }
      login(token);
    }
  }
}