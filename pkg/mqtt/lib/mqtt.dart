// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// MQTT client library for the [MQTT protocol](http://mqtt.org/), a lightweight
/// IoT pub/sub messaging protocol.
///
/// The implementation uses the [Paho C client
/// library](http://git.eclipse.org/c/paho/org.eclipse.paho.mqtt.c.git/about/).
///
/// Usage
/// -----
/// ### Subscribing to messages
///
/// ```dart
/// void main() {
///   // Create MQTT client and configure subscriptions
///   Client c = new Client('tcp://test.mosquitto.org:1883', 'test123-client2');
///   c.AddSubscriber('/foo/bar' , messageHandler);
///
///   // Start the subscription processing loop. This call is not blocking.
///   c.StartSubscriptionProcessing();
///
///   // Do other work
///
///   // Clean up (this ends the subscriptions)
///   c.Disconnect();
/// }
///
/// void messageHandler(String msg, String topic) {
///   print("Received message '$msg' on topic '$topic'");
/// }
/// ```
///
/// See ```/pkg/mqtt/subscribe-sample.dart/``` for additional details.
///
/// ### Publishing messages
///
/// ```dart
/// void main() {
///   // Create MQTT client and publish a message
///   Client c = new Client('tcp://test.mosquitto.org:1883', 'test123-client1');
///   c.Publish('Hello, World', '/foo/bar');
///
///   // Clean up
///   c.Disconnect();
/// }
/// ```
///
/// See ```/pkg/mqtt/publish-sample.dart/``` for additional details.
///
/// Dependencies
/// ------------
///
/// This Dart library depends on the [Paho C
/// library](https://github.com/eclipse/paho.mqtt.c).
/// It will load the Paho shared object file (.so file) dynamically at runtime.
/// Therefore the Paho shared object file needs to be copied into the Dartino
/// SDK. Follow these instructions to compile and copy the library:
///
/// 1. Get the Paho source code
/// ```
/// $ git clone git@github.com:eclipse/paho.mqtt.c.git
/// ```
///
/// 1. Compile the source code
///
/// *Note*: See the [Paho readme](https://github.com/eclipse/paho.mqtt.c/blob/master/README.md) for details.
///
/// ```
/// $ cd paho.mqtt.c/
/// $ make
/// ```
///
/// 1. Copy the library to the lib directory Dartino SDK (substitute `<Dartino
/// SDK location>` with the location where you installed the Dartino SDK, e.g.
/// ~/dartino-sdk/)
///
/// ```
/// $ cd paho.mqtt.c/
/// $ cp build/output/libpaho-mqtt3c.so <Dartino SDK location>/lib/
///
/// ```
///
/// Reporting issues
/// ----------------
///
/// Please file an issue [in the issue tracker](https://github.com/dartino/sdk/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).

library mqtt;

import 'dart:dartino';
import 'package:os/os.dart';
import 'package:immutable/immutable.dart';

import 'src/mqtt_client.dart';

/// Attempt to connect with MQTT 3.1.1, and if that fails, falls back to 3.1.
const int protocolVersionNegotiate = 0;
/// Connect only using MQTT 3.1
const int protocolVersionOnly_3_1 = 3;
/// Connect only using MQTT 3.1.1
const int protocolVersionOnly_3_1_1 = 4;

/// MQTT Client class
///
/// For sample code, see 'publish-sample.dart' and 'subscribe-sample.dart'.
class Client {
  final String _serverURI;
  final String _clientID;
  int protocolVersion = protocolVersionNegotiate;
  MQTTClient _mqttClient;
  var _subscribers = {};
  Process _processor;

  /// Create a new MQTT Client to MQTT server [_serverURI]. [_clientID] needs to
  /// be a unique ID amoung all client connected to the server.
  /// [protocolVersion] defaults to [protocolVersionNegotiate].
  Client(this._serverURI, this._clientID, {this.protocolVersion});

  /// Publish an MQTT [message] to subscribers listening to [topic].
  void publish(String message, String topic) {
    if (_mqttClient == null) {
      _mqttClient = new MQTTClient(_serverURI, _clientID,
        protocolVersion: protocolVersion);
    }

    if (! _mqttClient.isConnected()) {
      if (_mqttClient.connect() != MQTTCLIENT_SUCCESS) {
        throw new Exception("MQTT: Connection to $_serverURI failed");
      }
    }

    if (_mqttClient.publish(message, topic) != MQTTCLIENT_SUCCESS) {
      throw new Exception(
          "MQTT: Failed to publish message '$message' to topic '$topic'");
    }
  }

  /// Add a new subscription for [topic]. If a message is received, the
  /// `onReceived` handler will be called. Subscriptions will not begin
  /// processing before [StartSubscriptionProcessing()] is called. After
  /// processing has started, no additional handlers can be added.
  void addSubscriber(String topic, onReceived(String msg, String topic)) {
    // Test if we started processing subscriptions already. If so, throw a state
    // error.
    if (_processor != null)
      throw new StateError("MQTT: State error; subscribers cannot be added "
        "after subscription processing has started");
    } else {
      _subscribers[topic] = onReceived;
    }
  }

  /// Begin processing of incoming messages. If any received messages match
  /// topic subscribed to via the [AddSubscriber] event handlers will be called.
  /// The processing happens in a separate process, so this call non-blocking.
  void startSubscriptionProcessing() {
    if (_processor != null) {
      throw new StateError("MQTT: State error; subscription processing was "
        "already started");
    } else {
      // Convert maps to LinkedList as we do not have support for immutable
      // maps.
      LinkedList<String> topics =
          new LinkedList<String>.fromList(_subscribers.keys.toList());
      LinkedList<String> handlers =
          new LinkedList<String>.fromList(_subscribers.values.toList());

      // Copy these locally to make them immutable in the closure below.
      String server = _serverURI;
      String client = _clientID;
      int version = protocolVersion;

      // Spawn off the processor.
      _processor = Process.spawn(() => _messageProcessor(server, client,
        version, topics, handlers));
    }
  }

  /// Disconnect the client, and free all resources.
  void disconnect() {
    if (_mqttClient != null) {
      _mqttClient.disconnect(1000);
      _mqttClient.destroy();
    }

    // If the message processor is running: Kill it's process
    if (_processor != null) {
      _processor.kill();
    }
  }
}

void _messageProcessor(String serverURI, String clientID, int protocolVersion,
    LinkedList<String> topics, LinkedList<String> handlers) {
  // Connect the client
  MQTTClient mqttClient = new MQTTClient(serverURI, clientID,
    protocolVersion: protocolVersion);
  if (mqttClient.connect() != MQTTCLIENT_SUCCESS) {
    throw new Exception("MQTT: Connection to $serverURI failed");
  }

  // Convert the linked list of topics into a map to enable efficient topic
  // lookup when receiving messages.
  Map subscriptions = {};
  LinkedList<String> currentTopic = topics;
  LinkedList<String> currentHandler = handlers;
  while (currentTopic != null) {
    subscriptions[currentTopic.head] = currentHandler.head;
    currentTopic = currentTopic.tail;
    currentHandler = currentHandler.tail;
  }

  // Add all subscribers to the client.
  for (var topic in subscriptions.keys) {
    if (mqttClient.subscribe(topic, 0) != MQTTCLIENT_SUCCESS) {
      throw new Exception("MQTT: Failed to subscribe to topic '$topic'");
    }
  }

  // Loop and process messages.
  while (true) {
    Message msg = mqttClient.receive(60*1000);
    if (msg.result == MQTTCLIENT_SUCCESS) {
      // MQTT returns null messages when there are no new messages.
      if (msg.message != null) {
        if (subscriptions.containsKey(msg.topic)) {
          // Message received. Check if it has any subscribers.
          var handler = subscriptions[msg.topic];
          if (handler != null) {
            // Call the event handler for topic.
            handler(msg.message, msg.topic);
          }
        }
      }
    }
  }
}
