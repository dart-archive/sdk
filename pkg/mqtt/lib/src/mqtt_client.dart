// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';
import 'dart:fletch.ffi';
import 'package:ffi/ffi.dart';

// MQTT success value
const int MQTTCLIENT_SUCCESS = 0;

// Foreign functions from the native Paho library
final ForeignLibrary _mqttLib = new
    ForeignLibrary.fromName(ForeignLibrary.bundleLibraryName('paho-mqtt3c'));
final ForeignFunction _MQTTClient_create =
    _mqttLib.lookup('MQTTClient_create');
final ForeignFunction _MQTTClient_connect =
    _mqttLib.lookup('MQTTClient_connect');
final ForeignFunction _MQTTClient_isConnected =
    _mqttLib.lookup('MQTTClient_isConnected');
final ForeignFunction _MQTTClient_publish =
    _mqttLib.lookup('MQTTClient_publish');
final ForeignFunction _MQTTClient_subscribe =
    _mqttLib.lookup('MQTTClient_subscribe');
final ForeignFunction _MQTTClient_receive =
    _mqttLib.lookup('MQTTClient_receive');
final ForeignFunction _MQTTClient_freeMessage =
    _mqttLib.lookup('MQTTClient_freeMessage');
final ForeignFunction _MQTTClient_free =
    _mqttLib.lookup('MQTTClient_free');
final ForeignFunction _MQTTClient_disconnect =
    _mqttLib.lookup('MQTTClient_disconnect');
final ForeignFunction _MQTTClient_destroy =
    _mqttLib.lookup('MQTTClient_destroy');
const MQTTCLIENT_PERSISTENCE_NONE = 1;

class MQTTClient {
  ForeignMemory mqttClientHandle = new ForeignMemory.allocatedFinalized(8);
  ForeignPointer mqttClient;
  int protocolVersion;

  MQTTClient(String serverURI, String clientID, {this.protocolVersion}) {
    if (protocolVersion == null) protocolVersion = 0;

    // DLLExport int MQTTClient_create(
    //   MQTTClient* handle,
    //   const char* serverURI,
    //   const char* clientId,
    //   int persistence_type,
    //   void* persistence_context
    // );
    int result = _MQTTClient_create.icall$5(
        mqttClientHandle,
        new ForeignMemory.fromStringAsUTF8(serverURI),
        new ForeignMemory.fromStringAsUTF8(clientID),
        MQTTCLIENT_PERSISTENCE_NONE,
        ForeignPointer.NULL);
    if (result == MQTTCLIENT_SUCCESS) {
      // De-ref the client from the client handle.
      mqttClient = new ForeignPointer(mqttClientHandle.getInt64(0));
    } else {
      throw new Exception("MQTT: Failed to create client");
    }
  }

  int connect() {
    // DLLExport int MQTTClient_connect(
    //   MQTTClient handle,
    //   MQTTClient_connectOptions* options
    // );
    ConnectionOptionsStruct co = new ConnectionOptionsStruct();
    co.setInt32InMember('MQTTVersion', protocolVersion);
    return _MQTTClient_connect.icall$2(mqttClient, co);
  }


  bool isConnected() {
      // DLLExport int MQTTClient_isConnected(MQTTClient handle);
      int result = _MQTTClient_isConnected.icall$1(mqttClient);
      if (result == 1)
        return true;
      else
        return false;
  }

  int publish(String message, String topic) {
    // Initialize non-supported parameters.
    int QoS = 0;
    int retained = 0;

    // DLLExport int MQTTClient_publish(
    //   MQTTClient handle,
    //   const char* topicName,
    //   int payloadlen,
    //   void* payload,
    //   int qos,
    //   int retained,
    //   MQTTClient_deliveryToken* dt);
    return _MQTTClient_publish.icall$7(
        mqttClient,
        new ForeignMemory.fromStringAsUTF8(topic),
        message.length,
        new ForeignMemory.fromStringAsUTF8(message),
        QoS,
        retained,
        new ForeignMemory.allocatedFinalized(8));
  }

  int subscribe(String topic, int QoS) {
    // DLLExport int MQTTClient_subscribe(
    //   MQTTClient handle,
    //   const char* topic,
    //   int qos
    // );
    return _MQTTClient_subscribe.icall$3(
        mqttClient, new ForeignMemory.fromStringAsUTF8(topic), QoS);
  }

  Message receive(int timeout) {
    Message msg = new Message();

    // DLLExport int MQTTClient_receive(
    //   MQTTClient handle,
    //   char** topicName,
    //   int* topicLen,
    //   MQTTClient_message** message,
    //   unsigned long timeout
    // );
    ForeignMemory topicNameHandle = new ForeignMemory.allocatedFinalized(8);
    ForeignMemory topicLenHandle = new ForeignMemory.allocatedFinalized(8);
    ForeignMemory messageHandle = new ForeignMemory.allocatedFinalized(8);

    int result = _MQTTClient_receive.icall$5(
        mqttClient, topicNameHandle, topicLenHandle, messageHandle, timeout);
    msg.result = result;

    if (result == MQTTCLIENT_SUCCESS) {
      // Get the message.
      // If the messagePointer is empty, we did not actually receive anything.
      ForeignPointer messagePointer =
          new ForeignPointer(messageHandle.getInt64(0));
      if (messagePointer.address != 0) {
        // Decode the message struct
        //
        // typedef struct {
        //   char struct_id[4];
        //   int struct_version;
        //   int payloadlen;
        //   void* payload;
        //   int qos;
        //   int retained;
        //   int dup;
        //   int msgid;
        // } MQTTClient_message;

        // Get the payload
        ForeignMemory payload =
            new ForeignMemory.fromAddress(messagePointer.address, 100);
        ForeignPointer payloadPointer = new ForeignPointer(payload.getInt64(16));
        int payloadLength = payload.getInt32(8);
        msg.message = memoryToString(payloadPointer, payloadLength);

        // Get the topic
        int topicLength = topicLenHandle.getInt32(0);
        ForeignPointer topicPointer =
            new ForeignPointer(topicNameHandle.getInt64(0));
        msg.topic = memoryToString(topicPointer, topicLength);

        // DLLExport void MQTTClient_freeMessage(MQTTClient_message** msg);
        _MQTTClient_freeMessage.vcall$1(messageHandle);

        // DLLExport void MQTTClient_free(void* ptr);
        _MQTTClient_free.vcall$1(topicNameHandle);
      }
    }

    return msg;
  }

  void disconnect(int timeout) {
    // DLLExport int MQTTClient_disconnect(MQTTClient handle, int timeout);
    _MQTTClient_disconnect.icall$2(mqttClient, timeout);
  }

  void destroy() {
    // DLLExport void MQTTClient_destroy(MQTTClient* handle);
    _MQTTClient_destroy.icall$1(mqttClientHandle);
  }
}

class Message {
  int result;
  String message;
  String topic;
}

class ConnectionOptionsStruct extends IndexedStruct {

  static Map offsets = {
    'struct_id'             : [0, 0],
    'struct_version'        : [4, 4],
    'keepAliveInterval'     : [8, 8],
    'cleansession'          : [12, 12],
    'reliable'              : [16, 16],
    'will'                  : [20, 24],
    'username'              : [24, 32],
    'password'              : [28, 40],
    'connectTimeout'        : [32, 48],
    'retryInterval'         : [36, 52],
    'ssl'                   : [40, 56],
    'serverURIcount'        : [44, 64],
    'serverURIs'            : [48, 72],
    'MQTTVersion'           : [52, 80]
  };

  ConnectionOptionsStruct(): super(offsets) {
    // #define MQTTClient_connectOptions_initializer
    // { {'M', 'Q', 'T', 'C'},
    //   4, 60, 1, 1, NULL, NULL, NULL, 30, 20, NULL, 0, NULL, 0 }

    // Fill out the 'eyecatcher'.
    setInt8(0, 77); // ascii 'M'
    setInt8(1, 81); // ascii 'Q'
    setInt8(2, 84); // ascii 'T'
    setInt8(3, 67); // ascii 'C'

    // Set default values.
    setInt32InMember('struct_version', 4);
    setInt32InMember('keepAliveInterval', 60);
    setInt32InMember('cleansession', 1);
    setInt32InMember('reliable', 1);
    setInt32InMember('connectTimeout', 30);
    setInt32InMember('retryInterval', 20);
    setInt32InMember('MQTTVersion', 0);
  }
}

class IndexedStruct extends Struct {
  Map _offsets;

  IndexedStruct(Map offsets) : super.finalized(offsets.length) {
    _offsets = offsets;
  }

  void setInt32InMember(String member, int value) {
      var offsets = _offsets[member];
      if (offsets == null) throw "IndexedStruct: No member $member";

      switch (wordSize) {
        case 4:
          setInt32(offsets[0], value);
        case 8:
          setInt32(offsets[1], value);
        default:
          throw "IndexedStruct: Unsupported machine word size.";
      }
  }
}
