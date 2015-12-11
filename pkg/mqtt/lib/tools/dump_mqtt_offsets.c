#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include "MQTTClient.h"

#define DumpMemberOffset(type,member) ( \
  printf("'"#member"': [%i, %i]\n", \
    (int)offsetof(type,member), (int)offsetof(type,member)))

int main() {
  //                                offset 32 bit, 64 bit:
  // const char struct_id[4];       offset 0, 0
  // int struct_version;            offset 4, 4
  // int keepAliveInterval;         offset 8, 8
  // int cleansession;              offset 12 ,12
  // int reliable;                  offset 16, 16
  // MQTTClient_willOptions* will;  offset 20, 24
  // const char* username;          offset 24, 32
  // const char* password;          offset 28, 40
  // int connectTimeout;            offset 32, 48
  // int retryInterval;             offset 36, 52
  // MQTTClient_SSLOptions* ssl;    offset 40, 56
  // int serverURIcount;            offset 44, 64
  // char* const* serverURIs;       offset 48, 72
  // int MQTTVersion;               offset 52, 80

  DumpMemberOffset(MQTTClient_connectOptions, struct_id);
  DumpMemberOffset(MQTTClient_connectOptions, struct_version);
  DumpMemberOffset(MQTTClient_connectOptions, keepAliveInterval);
  DumpMemberOffset(MQTTClient_connectOptions, cleansession);
  DumpMemberOffset(MQTTClient_connectOptions, reliable);
  DumpMemberOffset(MQTTClient_connectOptions, will);
  DumpMemberOffset(MQTTClient_connectOptions, username);
  DumpMemberOffset(MQTTClient_connectOptions, password);
  DumpMemberOffset(MQTTClient_connectOptions, connectTimeout);
  DumpMemberOffset(MQTTClient_connectOptions, retryInterval);
  DumpMemberOffset(MQTTClient_connectOptions, ssl);
  DumpMemberOffset(MQTTClient_connectOptions, serverURIcount);
  DumpMemberOffset(MQTTClient_connectOptions, serverURIs);
  DumpMemberOffset(MQTTClient_connectOptions, MQTTVersion);

  return 0;
}
