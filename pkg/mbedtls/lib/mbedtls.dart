// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// TLS support, based on mbedtls. This can be used in the same way as a normal
/// Socket (and passed to the http package).
/// Usage
/// -----
/// The following sample code shows how to access an https server.
///
/// ```dart
/// import 'package:mbedtls/mbedtls.dart';
/// import 'package:http/http.dart';
///
/// main() {
///   var port = 443;
///   var host = "httpbin.org";
///   var socket = new TLSSocket.connect(host, port);
///   print("Connected to $host:$port");
///   var https = new HttpConnection(socket);
///   var request = new HttpRequest("/ip");
///   request.headers["Host"] = "httpbin.org";
///   var response = https.send(request);
///   var responseString = new String.fromCharCodes(response.body);
///   // Reponse looks like this
///   // {
///   //   "origin": "2.109.66.196"
///   // }
///   var ip = responseString.split('"')[3];
///   print("Hello $ip");
///   socket.close();
/// }
/// ```
/// Reporting issues
/// ----------------
/// Please file an issue [in the issue tracker](https://github.com/dartino/sdk/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
library mbedtls;

import 'dart:dartino.ffi';
import 'dart:dartino';
import 'dart:typed_data';
import 'package:os/os.dart';
import 'package:socket/socket.dart';
import 'package:ffi/ffi.dart';

final String mbedtlsLibraryName = ForeignLibrary.bundleLibraryName('mbedtls');
final ForeignLibrary lib = new ForeignLibrary.fromName(mbedtlsLibraryName);

// The functions below are named the same as their c counterpart.
final ForeignFunction entropy_context_sizeof =
    lib.lookup("entropy_context_sizeof");
final ForeignFunction ssl_context_sizeof =
    lib.lookup("ssl_context_sizeof");
final ForeignFunction ctr_drbg_context_sizeof =
    lib.lookup("ctr_drbg_context_sizeof");
final ForeignFunction ssl_config_sizeof =
    lib.lookup("ssl_config_sizeof");
final ForeignFunction x509_crt_sizeof =
    lib.lookup("x509_crt_sizeof");

final mbedtls_entropy_func =
    lib.lookup('mbedtls_entropy_func');
final mbedtls_ctr_drbg_seed =
    lib.lookup('mbedtls_ctr_drbg_seed');
final mbedtls_test_cas_pem =
    lib.lookup('mbedtls_test_cas_pem');
final mbedtls_test_cas_pem_len =
    lib.lookup('mbedtls_test_cas_pem_len');

final mbedtls_x509_crt_parse =
    lib.lookup('mbedtls_x509_crt_parse');
final mbedtls_ssl_config_defaults =
    lib.lookup('mbedtls_ssl_config_defaults');
final mbedtls_ssl_conf_authmode =
    lib.lookup('mbedtls_ssl_conf_authmode');
final mbedtls_ssl_conf_ca_chain =
    lib.lookup('mbedtls_ssl_conf_ca_chain');
final mbedtls_ssl_conf_rng =
    lib.lookup('mbedtls_ssl_conf_rng');
final mbedtls_ctr_drbg_random =
    lib.lookup('mbedtls_ctr_drbg_random');
final mbedtls_ssl_setup =
    lib.lookup('mbedtls_ssl_setup');
final mbedtls_ssl_set_hostname =
    lib.lookup('mbedtls_ssl_set_hostname');
final mbedtls_ssl_set_bio =
    lib.lookup('mbedtls_ssl_set_bio');
final mbedtls_ssl_handshake =
    lib.lookup('mbedtls_ssl_handshake');
final mbedtls_ssl_get_verify_result =
    lib.lookup('mbedtls_ssl_get_verify_result');
final mbedtls_x509_crt_verify_info =
    lib.lookup('mbedtls_x509_crt_verify_info');
final mbedtls_ssl_write =
    lib.lookup('mbedtls_ssl_write');
final mbedtls_ssl_read =
    lib.lookup('mbedtls_ssl_read');
final mbedtls_ssl_get_bytes_avail =
    lib.lookup('mbedtls_ssl_get_bytes_avail');
final mbedtls_ssl_close_notify =
    lib.lookup('mbedtls_ssl_close_notify');

final mbedtls_x509_crt_free =
    lib.lookup('mbedtls_x509_crt_free');
final mbedtls_ssl_free =
    lib.lookup('mbedtls_ssl_free');
final mbedtls_ssl_config_free =
    lib.lookup('mbedtls_ssl_config_free');
final mbedtls_ctr_drbg_free =
    lib.lookup('mbedtls_ctr_drbg_free');
final mbedtls_entropy_free =
    lib.lookup('mbedtls_entropy_free');

final mbedtls_ssl_init =
  lib.lookup('mbedtls_ssl_init');
final mbedtls_ssl_config_init =
  lib.lookup('mbedtls_ssl_config_init');
final mbedtls_x509_crt_init =
  lib.lookup('mbedtls_x509_crt_init');
final mbedtls_ctr_drbg_init =
  lib.lookup('mbedtls_ctr_drbg_init');
final mbedtls_entropy_init =
  lib.lookup('mbedtls_entropy_init');

// The function sending send requests back to dart.
final dart_send =
    lib.lookup('dart_send');
// The function sending recv requests back to dart.
final dart_recv =
    lib.lookup('dart_recv');


/**
 * A TLS socket build on top of the mbed tls library.
 * This file is mostly a wrapper based loosely on the programs/ssl/ssl_client1
 * in the mbedtls library.
 */
class TLSSocket implements Socket {
  static const int MBEDTLS_NET_PROTO_TCP = 0;
  static const int MBEDTLS_SSL_IS_CLIENT = 0;
  static const int MBEDTLS_SSL_TRANSPORT_STREAM = 0;
  static const int MBEDTLS_SSL_PRESET_DEFAULT = 0;
  static const int MBEDTLS_SSL_VERIFY_OPTIONAL = 1;
  static const int MBEDTLS_ERR_SSL_WANT_READ = -0x6900;
  static const int MBEDTLS_ERR_SSL_WANT_WRITE = -0x6880;
  static const int MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY = -0x7880;

  // All names here are kept as close as possible to:
  // programs/ssl/ssl_client1.c in the mbedtls repository.
  final ssl =
      new ForeignMemory.allocatedFinalized(ssl_context_sizeof.icall$0());
  final conf =
      new ForeignMemory.allocatedFinalized(ssl_config_sizeof.icall$0());
  final cacert =
      new ForeignMemory.allocatedFinalized(x509_crt_sizeof.icall$0());
  final ctr_drbg =
      new ForeignMemory.allocatedFinalized(ctr_drbg_context_sizeof.icall$0());
  final entropy =
      new ForeignMemory.allocatedFinalized(entropy_context_sizeof.icall$0());

  // The dartino socket we use to do the actual network communication.
  Socket _socket;

  final String server;
  final int port;

  CircularByteBuffer _sendBuffer;
  CircularByteBuffer _recvBuffer;
  ForeignMemory _foreignBuffers;

  int _getSize_tValue(ForeignPointer ptr) {
    var memory = new ForeignMemory.fromAddress(ptr.address,
                                               Foreign.machineWordSize);
    switch (Foreign.machineWordSize) {
      case 4:
        return memory.getInt32(0);
      case 8:
        return memory.getInt64(0);
      default:
        throw new TLSException("Unsupported word size.");
    }
  }

  /**
   * Connect the socket and do the initial handshake.
   */
  TLSSocket.connect(String this.server, int this.port,
                    {bool failOnCertificate: false}) {
    _socket = new Socket.connect(server, port);
    _sendBuffer = new CircularByteBuffer(1024);
    _recvBuffer = new CircularByteBuffer(1024);
    _foreignBuffers = _getForeignFromBuffers(_sendBuffer, _recvBuffer);
    mbedtls_ssl_init.vcall$1(ssl);
    mbedtls_ssl_config_init.vcall$1(conf);
    mbedtls_x509_crt_init.vcall$1(cacert);
    mbedtls_ctr_drbg_init.vcall$1(ctr_drbg);
    mbedtls_entropy_init.vcall$1(entropy);
    var pers =
        new ForeignMemory.fromStringAsUTF8('ssl_client_dartino');
    var result = mbedtls_ctr_drbg_seed.icall$5(ctr_drbg, mbedtls_entropy_func,
                                               entropy, pers, pers.length);
    pers.free();
    if (result != 0) {
      throw new TLSException(
          "mbedtls_ctr_drbg_seed returned non 0 value of $result");
    }

    var mbedtls_test_cas_pem_len_size =
        _getSize_tValue(mbedtls_test_cas_pem_len);
    result = mbedtls_x509_crt_parse.icall$3(cacert, mbedtls_test_cas_pem,
                                            mbedtls_test_cas_pem_len_size);
    if (result != 0) {
      throw new TLSException(
          "mbedtls_x509_crt_parse returned non 0 value $result");
    }

    result = mbedtls_ssl_config_defaults.icall$4(conf,
                                                 MBEDTLS_SSL_IS_CLIENT,
                                                 MBEDTLS_SSL_TRANSPORT_STREAM,
                                                 MBEDTLS_SSL_PRESET_DEFAULT);
    if (result != 0) {
      throw new TLSException(
          "mbedtls_ssl_config_defaults returned non 0 value: $result");
    }

    mbedtls_ssl_conf_authmode.vcall$2(conf,  MBEDTLS_SSL_VERIFY_OPTIONAL);
    mbedtls_ssl_conf_ca_chain.vcall$3(conf, cacert, ForeignPointer.NULL);
    mbedtls_ssl_conf_rng.vcall$3(conf, mbedtls_ctr_drbg_random, ctr_drbg);
    result = mbedtls_ssl_setup.icall$2(ssl, conf);
    if (result != 0) {
      throw new TLSException("mbedtls_ssl_setup returned non 0 value $result");
    }
    var serverHostName = new ForeignMemory.fromStringAsUTF8('no_used');
    result = mbedtls_ssl_set_hostname.icall$2(ssl, serverHostName);
    serverHostName.free();
    if (result != 0) {
      throw new TLSException(
          "mbedtls_ssl_set_hostname returned non 0 value $result");
    }
    mbedtls_ssl_set_bio.vcall$5(ssl, _foreignBuffers.address, dart_send,
                                dart_recv, ForeignPointer.NULL);
    result = mbedtls_ssl_handshake.icall$1(ssl);
    while (_handleBuffers(result)) {
      result = mbedtls_ssl_handshake.icall$1(ssl);
    }
    if (result < 0) {
      throw new TLSException(
          "mbedtls_ssl_handshake returned ${result.toRadixString(16)}");
    }

    var flags = mbedtls_ssl_get_verify_result.icall$1(ssl);
    // In real life, we probably want to bail out when flags != 0
    if (flags != 0 && failOnCertificate) {
      var vrfy_buf = new ForeignMemory.allocatedFinalized(512);
      var input = new ForeignMemory.fromStringAsUTF8('  !  ');
      mbedtls_x509_crt_verify_info.vcall$4(vrfy_buf, vrfy_buf.length,
                                           input, flags);
      input.free();
      throw new TLSException(cStringToString(vrfy_buf));
    }
  }

  bool _handleBuffers(int ret) {
    _throwIfClosed();
    if (_sendBuffer.available > 0) {
      Uint8List list = new Uint8List(_sendBuffer.available);
      _sendBuffer.read(list.buffer);
      _socket.write(list.buffer);
    }
    if (ret == MBEDTLS_ERR_SSL_WANT_READ) {
      ByteBuffer readBuffer = _socket.readNext(_recvBuffer.freeSpace);
      if (readBuffer == null) {
        throw new TLSException.closed();
      }
      _recvBuffer.write(readBuffer);
    }
    return (ret == MBEDTLS_ERR_SSL_WANT_READ ||
            ret == MBEDTLS_ERR_SSL_WANT_WRITE);
  }

  ForeignMemory _getForeignFromBuffers(CircularByteBuffer sendBuffer,
                                       CircularByteBuffer recvBuffer) {
    var buffers =
        new ForeignMemory.allocatedFinalized(Foreign.machineWordSize * 2);
    switch (Foreign.machineWordSize) {
      case 4:
        buffers.setInt32(0, sendBuffer.foreign.address);
        buffers.setInt32(Foreign.machineWordSize, recvBuffer.foreign.address);
      case 8:
        buffers.setInt64(0, sendBuffer.foreign.address);
        buffers.setInt64(Foreign.machineWordSize, recvBuffer.foreign.address);
      default:
        throw new TLSException("Unsupported word size.");
    }
    return buffers;
  }

  /**
   * Close the socket and free all of the ssl resources.
   * Please note that this function _must_ be called to not leak resources.
   * We have an issue here if a given process is killed from the side,
   * the actual structs created here will be freed since they are allocated
   * finalized, but the resources allocated by the mbedtls library will not
   * be freed since we have no way of registering dealloc callbacks.
   */
  void close() {
    _throwIfClosed();
    mbedtls_ssl_close_notify.icall$1(ssl);
    mbedtls_x509_crt_free.icall$1(cacert);
    mbedtls_ssl_free.icall$1(ssl);
    mbedtls_ssl_config_free.icall$1(conf);
    mbedtls_ctr_drbg_free.icall$1(ctr_drbg);
    mbedtls_entropy_free.icall$1(entropy);
    // The free calls above does not actually free the structs, just all
    // referenced structs.
    ssl.free();
    cacert.free();
    conf.free();
    ctr_drbg.free();
    entropy.free();
    _socket.close();
    _socket = null;
  }

  void shutdownWrite() {
    _throwIfClosed();
    _socket.shutdownWrite();
  }

  ByteBuffer _stringToByteBuffer(String str) {
    Uint8List list = new Uint8List(str.length);
    for (int i = 0; i < list.length; i++) {
      list[i] = str.codeUnitAt(i);
    }
    return list.buffer;
  }

  /**
   * Write the string to the secure socket.
   */
  void writeString(String s) {
    write(_stringToByteBuffer(s));
  }

  void _throwIfClosed() {
    if (_socket == null) {
      throw new TLSException.closed();
    }
  }

  /**
   * Write the buffer to the secure socket.
   */
  void write(ByteBuffer buffer) {
    _throwIfClosed();
    // getForeign is not public, TODO(ricow): revisit this
    var buf = buffer;
    var foreign = buf.getForeign();
    var ret = mbedtls_ssl_write.icall$3(ssl, foreign, buffer.lengthInBytes);
    while (_handleBuffers(ret)) {
       ret = mbedtls_ssl_write.icall$3(ssl, foreign, buffer.lengthInBytes);
    }
    if (ret < 0) {
      throw new TLSException(
          " failed\n  ! mbedtls_ssl_write returned $ret\n\n");
    }
    // Push the last written to the socket.
    _handleBuffers(ret);
  }

  int get available {
    _throwIfClosed();
    // There are two possible buffers that are in play here:
    // * The buffer in the socket
    // * The buffer in the tls layer
    // The tls layer will not read the bytes from the socket until we actually
    // do a read, but we can trigger the transfer of bytes by doing a null read.

    // If there are available bytes on the socket we issue a null read on the
    // tls socket to get the bits through.
    if (_socket.available > 0) {
      int ret = mbedtls_ssl_read.icall$3(ssl, ForeignPointer.NULL, 0);
      while (_handleBuffers(ret)) {
        ret = mbedtls_ssl_read.icall$3(ssl, ForeignPointer.NULL, 0);
      }
    }
    int available = mbedtls_ssl_get_bytes_avail.icall$1(ssl);
    return available;
  }

  /**
   * Reads data from our socket until the buffer is full. If the bufer can't
   * be filled (connection closed, error from mbedtls, eof before full) we
   * return null;
   */
  ByteBuffer _readInto(var buffer) {
    int offset = 0;
    int bytes = buffer.lengthInBytes;
    int max = bytes;
    while (offset < bytes) {
      var ret = mbedtls_ssl_read.icall$3(ssl,
                                         buffer.getForeign().address + offset,
                                         max);
      if (_handleBuffers(ret)) {
        continue;
      } else if (ret <= 0) {  // 0 means EOF, < 0 error.
        return null;
      }
      offset += ret;
      max -= ret;
    }
    return buffer;
  }

  /**
   * Read [bytes] bytes from the tls socket. This will block until we have
   * enough data.
   */
  ByteBuffer read(int bytes) {
    // This is highly inefficient, we should allow to reuse the buffer.
    var buffer = new Uint8List(bytes).buffer;
    return _readInto(buffer);
  }

  /**
   * Bloks until data is available, reads and returns up to [max] bytes.
   * We never read more than 65535 bytes
   */
  ByteBuffer readNext([int max = 65535]) {
    _throwIfClosed();
    // If there are no available bytes we do a null read, which will block in
    // the dart socket.
    while (available == 0) {
      var ret = mbedtls_ssl_read.icall$3(ssl, ForeignPointer.NULL, 0);
      _handleBuffers(ret);
    }
    int bytes = max < available ? max : available;
    return read(bytes);
  }
}

class TLSException implements Exception {
  final String message;

  TLSException(this.message);
  TLSException.closed() : message = "The underlying socket was closed";

  String toString() => "TLSException: $message";
}
