import 'package:mqtt/mqtt.dart';
import 'package:os/os.dart';

// Sample code for subscribing to and receiving messages.
//
// For an end-to-end sample, run this program first, and then start
// publish-sample.dart next to see the communication between the two.
void main() {
  // Create MQTT client and configure subscriptions.
  Client c = new Client('tcp://test.mosquitto.org:1883', 'test123-client2',
    protocolVersion: 3);
  c.addSubscriber('/foo/bar' , messageHandler);
  c.addSubscriber('/foo/baz', messageHandler);

  // Start the subscription processing loop. This call is not blocking.
  c.startSubscriptionProcessing();

  // Note how we can do additional work while receiving messages.
  int i = 0;
  while (i <= 60) {
    print('Main running for $i seconds');
    sleep(5000);
    i += 5;
  }

  // Clean up.
  c.disconnect();
}

void messageHandler(String msg, String topic) {
  print("Received message '$msg' on topic '$topic'");
}
