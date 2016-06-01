// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Sample that connects to a http server to get a weather forecast,
// and then prints that to the screen.
//
// Notes:
// 1. This sample requires an Internet connection.
// 2. The http server called requires a appid key, available by registering
//    at http://openweathermap.org. This needs to be added in line 20.
import 'dart:convert';
import 'dart:dartino.ffi';
import 'dart:dartino' show sleep;
import 'package:socket/socket.dart';
import 'package:http/http.dart';
import 'package:stm32/ethernet.dart';

// TODO: Add your own APPID from openweathermap.org here.
var APPID = '';
// TODO: Change this to the location you are interested in.
var myLocation = 'Aarhus';

main() {
  // If we are running on a dev board, we need to initialize the network.
  if (Foreign.platform == Foreign.FREERTOS) {
    initializeNetwork();
  }

  // Get the current weather.
  WeatherInfo wd = getCurrentWeather(myLocation);
  print(wd);
}

class WeatherInfo {
  final int temperature;
  final int pressure;
  final String description;
  final String location;

  WeatherInfo(this.temperature, this.pressure, this.description, this.location);

  String toString() {
    var buffer = new StringBuffer();
    buffer.writeln("Current weather in '$location':");
    buffer.writeln(" - conditions: $description");
    buffer.writeln(" - temperature: $temperature");
    buffer.writeln(" - pressure: $pressure");
    return buffer.toString();
  }
}

WeatherInfo getCurrentWeather(String location) {
  // Create and send the http request.
  var uri = new Uri(
    path: "/data/2.5/weather",
    queryParameters: {
      'q': location,
      'APPID': APPID,
      'units': 'metric'
    }
  );
  var host = 'api.openweathermap.org';
  var socket = new Socket.connect(host, 80);
  var http = new HttpConnection(socket);
  var request = new HttpRequest(uri.toString());
  request.headers["Host"] = host;
  print("Sending an ${uri.toString()} request to $host:80");
  var response = http.send(request);

  // If we got back status OK/200, parse the JSON formatted response.
  WeatherInfo result;
  print("Status: ${response.statusCode}");
  if (response.statusCode == HttpStatus.OK) {
    Map data = JSON.decode(new String.fromCharCodes(response.body));
    int temperature = data['main']['temp'];
    int pressure = data['main']['pressure'];
    String description = data['weather'][0]['description'];
    result = new WeatherInfo(temperature, pressure, description, location);
  }
  socket.close();
  return result;
}


// Initialize the network stack and wait until the network interface has either
// received an IP address using DHCP or given up and used the provided
// fallback [address].
const fallbackAddress = const InternetAddress(const <int>[192, 168, 0, 10]);
const fallbackNetmask = const InternetAddress(const <int>[255, 255, 255, 0]);
const fallbackGateway = const InternetAddress(const <int>[192, 168, 0, 1]);
const fallbackDnsServer = const InternetAddress(const <int>[8, 8, 8, 8]);

void initializeNetwork({
  InternetAddress address: fallbackAddress,
  InternetAddress netmask: fallbackNetmask,
  InternetAddress gateway: fallbackGateway,
  InternetAddress dnsServer: fallbackDnsServer}) {

  if (!ethernet.initializeNetworkStack(address, netmask, gateway, dnsServer)) {
    throw "Failed to initialize network stack";
  }

  while (NetworkInterface.list().first.addresses.isEmpty) {
    sleep(10);
  }
}
