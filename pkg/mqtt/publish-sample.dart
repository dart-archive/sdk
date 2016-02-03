import 'dart:dartino';
import 'package:mqtt/mqtt.dart';

// Sample code for publishing messages.
//
// For an end-to-end sample, first run subscribe-sample.dart, and then start
// this program next to see the communication between the two. Note that this
// program has to be started in a second session, e.g. `dartino start
// publish-sample.dart in session 2'.
void main() {
  // Create MQTT client.
  Client c = new Client('tcp://test.mosquitto.org:1883', 'test123-client1',
    protocolVersion: 3);

  // Publish some messages.
  for (int i = 1; i <= 3; i++) {
    c.publish('Message $i', '/foo/bar');
    c.publish('Message $i', '/foo/baz');
  }

  // Clean up.
  c.disconnect();
}
