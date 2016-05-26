// Copyright (c) 2014-2015, Nicolas François
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <cstring>
#include <stdlib.h>
#include <sstream>
#include <stdio.h>
#include <fcntl.h>
#include "include/dart_api.h"
#include "include/dart_native_api.h"
#include "native_helper.h"
#include "serial_port.h"


Dart_NativeFunction ResolveName(Dart_Handle name, int argc, bool *auto_setup_scope);

Dart_Handle HandleError(Dart_Handle handle);

enum METHOD_CODE {
  TEST_PORT = 0,
  OPEN = 1,
  CLOSE = 2,
  READ = 3,
  WRITE = 4,
  WRITE_BYTE = 5 // TODO delete with the real write by bytes implementation.
};

DECLARE_DART_NATIVE_METHOD(native_test_port){
  DECLARE_DART_RESULT;
  const char* port_name = GET_STRING_ARG(0);

  bool valid = testSerialPort(port_name);

  SET_RESULT_BOOL(valid);
  RETURN_DART_RESULT;
}

DECLARE_DART_NATIVE_METHOD(native_open){
  DECLARE_DART_RESULT;
  const char* port_name = GET_STRING_ARG(0);
  int64_t baudrate_speed = GET_INT_ARG(1);
  int64_t databits_nb = GET_INT_ARG(2);
  int parityCode = GET_INT_ARG(3);
  int stopbitsCode = GET_INT_ARG(4);

  int baudrate = selectBaudrate(baudrate_speed);
  if(baudrate == -1){
     SET_ERROR("Invalid baudrate");
     RETURN_DART_RESULT;
  }
  int databits = selectDataBits(databits_nb);
  if(databits == -1) {
     SET_ERROR("Invalid databits");
     RETURN_DART_RESULT;
  }
  parity_t parity = static_cast<parity_t>(parityCode);
  stopbits_t stopbits = static_cast<stopbits_t>(stopbitsCode);

  int tty_fd = openSerialPort(port_name, baudrate, databits, parity, stopbits);

  if(tty_fd < 0){
    SET_ERROR("Invalid access");
  }
  SET_RESULT_INT(tty_fd);
  RETURN_DART_RESULT;
}

DECLARE_DART_NATIVE_METHOD(native_close){
  DECLARE_DART_RESULT;
  int tty_fd = GET_INT_ARG(0);

  bool isClose = closeSerialPort(tty_fd);

  if(!isClose){
    SET_ERROR("Impossible to close");
    RETURN_DART_RESULT;
  }

  RETURN_DART_RESULT;
}

DECLARE_DART_NATIVE_METHOD(native_write){
  DECLARE_DART_RESULT;
  int64_t tty_fd = GET_INT_ARG(0);
  const char* data = GET_STRING_ARG(1);

  int length = writeToSerialPort(tty_fd, data);

  if(length <0){
    SET_ERROR("Impossible to write");
    RETURN_DART_RESULT;
  }

  SET_RESULT_INT(length);

  RETURN_DART_RESULT;
}

DECLARE_DART_NATIVE_METHOD(native_write_byte){
  DECLARE_DART_RESULT;
  int64_t tty_fd = GET_INT_ARG(0);
  int8_t byte = GET_INT_ARG(1);
  int length = writeToSerialPort(tty_fd, byte);
  if(length <0){
    SET_ERROR("Impossible to write");
    RETURN_DART_RESULT;
  }
  SET_RESULT_INT(length);
  RETURN_DART_RESULT;
}

DECLARE_DART_NATIVE_METHOD(native_read){
  DECLARE_DART_RESULT;
  int64_t tty_fd = GET_INT_ARG(0);
  int buffer_size = (int) GET_INT_ARG(1);
  uint8_t* data = reinterpret_cast<uint8_t*>(malloc(buffer_size * sizeof(uint8_t)));
  int bytes_read = readFromSerialPort(tty_fd, data, buffer_size);
  if(bytes_read > 0){
    SET_INT_ARRAY_RESULT(data, bytes_read);
  }
  RETURN_DART_RESULT;
}

DART_EXT_DISPATCH_METHOD()
  SWITCH_METHOD_CODE {
    case TEST_PORT:
      CALL_DART_NATIVE_METHOD(native_test_port);
      break;
    case OPEN :
      CALL_DART_NATIVE_METHOD(native_open);
      break;
    case CLOSE:
      CALL_DART_NATIVE_METHOD(native_close);
      break;
    case READ:
      CALL_DART_NATIVE_METHOD(native_read);
      break;
    case WRITE:
      CALL_DART_NATIVE_METHOD(native_write);
      break;
    case WRITE_BYTE:
      CALL_DART_NATIVE_METHOD(native_write_byte);
      break;
    default:
     UNKNOW_METHOD_CALL;
     break;
  }
}

DART_EXT_DECLARE_LIB(serial_port, serialPortServicePort)
