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
import 'dart:typed_data';
import 'package:os/os.dart';
import 'package:socket/socket.dart';
// TODO(karlklose): merge both implementations and remove this dependency.
import 'package:stm32/socket.dart' as stm;
import 'package:ffi/ffi.dart';

final ForeignLibrary _lib = _mbedTlsLibrary;

// The functions below are named the same as their c counterpart.
final ForeignFunction _entropy_context_sizeof =
    _lib.lookup("entropy_context_sizeof");
final ForeignFunction _ssl_context_sizeof =
    _lib.lookup("ssl_context_sizeof");
final ForeignFunction _ctr_drbg_context_sizeof =
    _lib.lookup("ctr_drbg_context_sizeof");
final ForeignFunction _ssl_config_sizeof =
    _lib.lookup("ssl_config_sizeof");
final ForeignFunction _x509_crt_sizeof =
    _lib.lookup("x509_crt_sizeof");

final _mbedtls_entropy_func =
    _lib.lookup('mbedtls_entropy_func');
final _mbedtls_ctr_drbg_seed =
    _lib.lookup('mbedtls_ctr_drbg_seed');
final _mbedtls_test_cas_pem =
    _lib.lookup('mbedtls_test_cas_pem');
final _mbedtls_test_cas_pem_len =
    _lib.lookup('mbedtls_test_cas_pem_len');

final _mbedtls_x509_crt_parse =
    _lib.lookup('mbedtls_x509_crt_parse');
final _mbedtls_ssl_config_defaults =
    _lib.lookup('mbedtls_ssl_config_defaults');
final _mbedtls_ssl_conf_authmode =
    _lib.lookup('mbedtls_ssl_conf_authmode');
final _mbedtls_ssl_conf_ca_chain =
    _lib.lookup('mbedtls_ssl_conf_ca_chain');
final _mbedtls_ssl_conf_rng =
    _lib.lookup('mbedtls_ssl_conf_rng');
final _mbedtls_ctr_drbg_random =
    _lib.lookup('mbedtls_ctr_drbg_random');
final _mbedtls_ssl_setup =
    _lib.lookup('mbedtls_ssl_setup');
final _mbedtls_ssl_set_hostname =
    _lib.lookup('mbedtls_ssl_set_hostname');
final _mbedtls_ssl_set_bio =
    _lib.lookup('mbedtls_ssl_set_bio');
final _mbedtls_ssl_handshake =
    _lib.lookup('mbedtls_ssl_handshake');
final _mbedtls_ssl_get_verify_result =
    _lib.lookup('mbedtls_ssl_get_verify_result');
final _mbedtls_x509_crt_verify_info =
    _lib.lookup('mbedtls_x509_crt_verify_info');
final _mbedtls_ssl_write =
    _lib.lookup('mbedtls_ssl_write');
final _mbedtls_ssl_read =
    _lib.lookup('mbedtls_ssl_read');
final _mbedtls_ssl_get_bytes_avail =
    _lib.lookup('mbedtls_ssl_get_bytes_avail');
final _mbedtls_ssl_close_notify =
    _lib.lookup('mbedtls_ssl_close_notify');

final _mbedtls_x509_crt_free =
    _lib.lookup('mbedtls_x509_crt_free');
final _mbedtls_ssl_free =
    _lib.lookup('mbedtls_ssl_free');
final _mbedtls_ssl_config_free =
    _lib.lookup('mbedtls_ssl_config_free');
final _mbedtls_ctr_drbg_free =
    _lib.lookup('mbedtls_ctr_drbg_free');
final _mbedtls_entropy_free =
    _lib.lookup('mbedtls_entropy_free');

final _mbedtls_ssl_init =
  _lib.lookup('mbedtls_ssl_init');
final _mbedtls_ssl_config_init =
  _lib.lookup('mbedtls_ssl_config_init');
final _mbedtls_x509_crt_init =
  _lib.lookup('mbedtls_x509_crt_init');
final _mbedtls_ctr_drbg_init =
  _lib.lookup('mbedtls_ctr_drbg_init');
final _mbedtls_entropy_init =
  _lib.lookup('mbedtls_entropy_init');

// The function sending send requests back to dart.
final _dart_send =
    _lib.lookup('dart_send');
// The function sending recv requests back to dart.
final _dart_recv =
    _lib.lookup('dart_recv');


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
  final _ssl =
      new ForeignMemory.allocatedFinalized(_ssl_context_sizeof.icall$0());
  final _conf =
      new ForeignMemory.allocatedFinalized(_ssl_config_sizeof.icall$0());
  final _cacert =
      new ForeignMemory.allocatedFinalized(_x509_crt_sizeof.icall$0());
  final _ctr_drbg =
      new ForeignMemory.allocatedFinalized(_ctr_drbg_context_sizeof.icall$0());
  final _entropy =
      new ForeignMemory.allocatedFinalized(_entropy_context_sizeof.icall$0());

  // TODO(karlklose): change type back to Socket when the STM32 implementation
  // fully supports the interface.
  /// The dartino socket we use to do the actual network communication.
  var _socket;

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
    _socket = _isFreeRTOS
      ? new stm.Socket.connect(server, port)
      : new Socket.connect(server, port);
    _sendBuffer = new CircularByteBuffer(1024);
    _recvBuffer = new CircularByteBuffer(1024);
    _foreignBuffers = _getForeignFromBuffers(_sendBuffer, _recvBuffer);
    _mbedtls_ssl_init.vcall$1(_ssl);
    _mbedtls_ssl_config_init.vcall$1(_conf);
    _mbedtls_x509_crt_init.vcall$1(_cacert);
    _mbedtls_ctr_drbg_init.vcall$1(_ctr_drbg);
    _mbedtls_entropy_init.vcall$1(_entropy);
    var pers =
        new ForeignMemory.fromStringAsUTF8('ssl_client_dartino');
    var result = _mbedtls_ctr_drbg_seed.icall$5(_ctr_drbg, _mbedtls_entropy_func,
        _entropy, pers, pers.length);
    pers.free();
    if (result != 0) {
      throw new TLSException(
          "mbedtls_ctr_drbg_seed returned non 0 value of $result");
    }

    var mbedtls_test_cas_pem_len_size =
        _getSize_tValue(_mbedtls_test_cas_pem_len);
    result = _mbedtls_x509_crt_parse.icall$3(_cacert, _mbedtls_test_cas_pem,
        mbedtls_test_cas_pem_len_size);
    if (result != 0) {
      throw new TLSException(
          "mbedtls_x509_crt_parse returned non 0 value $result");
    }

    result = _mbedtls_ssl_config_defaults.icall$4(
        _conf,
        MBEDTLS_SSL_IS_CLIENT,
        MBEDTLS_SSL_TRANSPORT_STREAM,
        MBEDTLS_SSL_PRESET_DEFAULT);
    if (result != 0) {
      throw new TLSException(
          "mbedtls_ssl_config_defaults returned non 0 value: $result");
    }

    _mbedtls_ssl_conf_authmode.vcall$2(_conf,  MBEDTLS_SSL_VERIFY_OPTIONAL);
    _mbedtls_ssl_conf_ca_chain.vcall$3(_conf, _cacert, ForeignPointer.NULL);
    _mbedtls_ssl_conf_rng.vcall$3(_conf, _mbedtls_ctr_drbg_random, _ctr_drbg);
    result = _mbedtls_ssl_setup.icall$2(_ssl, _conf);
    if (result != 0) {
      throw new TLSException("mbedtls_ssl_setup returned non 0 value $result");
    }
    var serverHostName = new ForeignMemory.fromStringAsUTF8('no_used');
    result = _mbedtls_ssl_set_hostname.icall$2(_ssl, serverHostName);
    serverHostName.free();
    if (result != 0) {
      throw new TLSException(
          "mbedtls_ssl_set_hostname returned non 0 value $result");
    }
    _mbedtls_ssl_set_bio.vcall$5(_ssl, _foreignBuffers.address, _dart_send,
        _dart_recv, ForeignPointer.NULL);
    result = _mbedtls_ssl_handshake.icall$1(_ssl);
    while (_handleBuffers(result)) {
      result = _mbedtls_ssl_handshake.icall$1(_ssl);
    }
    if (result < 0) {
      throw new TLSException(
          "mbedtls_ssl_handshake returned ${result.toRadixString(16)}");
    }

    var flags = _mbedtls_ssl_get_verify_result.icall$1(_ssl);
    // In real life, we probably want to bail out when flags != 0
    if (flags != 0 && failOnCertificate) {
      var vrfy_buf = new ForeignMemory.allocatedFinalized(512);
      var input = new ForeignMemory.fromStringAsUTF8('  !  ');
      _mbedtls_x509_crt_verify_info.vcall$4(vrfy_buf, vrfy_buf.length,
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
        break;
      case 8:
        buffers.setInt64(0, sendBuffer.foreign.address);
        buffers.setInt64(Foreign.machineWordSize, recvBuffer.foreign.address);
        break;
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
    _mbedtls_ssl_close_notify.icall$1(_ssl);
    _mbedtls_x509_crt_free.icall$1(_cacert);
    _mbedtls_ssl_free.icall$1(_ssl);
    _mbedtls_ssl_config_free.icall$1(_conf);
    _mbedtls_ctr_drbg_free.icall$1(_ctr_drbg);
    _mbedtls_entropy_free.icall$1(_entropy);
    // The free calls above does not actually free the structs, just all
    // referenced structs.
    _ssl.free();
    _cacert.free();
    _conf.free();
    _ctr_drbg.free();
    _entropy.free();
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
    var ret = _mbedtls_ssl_write.icall$3(_ssl, foreign, buffer.lengthInBytes);
    while (_handleBuffers(ret)) {
       ret = _mbedtls_ssl_write.icall$3(_ssl, foreign, buffer.lengthInBytes);
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
      int ret = _mbedtls_ssl_read.icall$3(_ssl, ForeignPointer.NULL, 0);
      while (_handleBuffers(ret)) {
        ret = _mbedtls_ssl_read.icall$3(_ssl, ForeignPointer.NULL, 0);
      }
    }
    int available = _mbedtls_ssl_get_bytes_avail.icall$1(_ssl);
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
      var ret = _mbedtls_ssl_read.icall$3(_ssl,
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
      var ret = _mbedtls_ssl_read.icall$3(_ssl, ForeignPointer.NULL, 0);
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

bool get _isFreeRTOS => Foreign.platform == Foreign.FREERTOS;

/// Switch between statically linked and dynamically linked library depending on
/// the platform.
/// Currently only FreeRTOS is statically linked.
ForeignLibrary get _mbedTlsLibrary {
  if (_isFreeRTOS) {
    return ForeignLibrary.main;
  } else {
    String mbedtlsLibraryName = ForeignLibrary.bundleLibraryName('mbedtls');
    return new ForeignLibrary.fromName(mbedtlsLibraryName);
  }
}
