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

#include <stdint.h>

typedef enum {
  ONE = 0,
  TWO = 1,
  //ONE_HALF = 1,
} stopbits_t;

typedef enum {
  NONE = 0,
  ODD = 1,
  EVEN = 2
} parity_t;

int selectBaudrate(int baudrate_speed);

int selectDataBits(int dataBits);

bool testSerialPort(const char* port_name);

int openSerialPort(const char* port_name, int baudrate, int databits, parity_t parity, stopbits_t stopbits);

bool closeSerialPort(int tty_fd);

int readFromSerialPort(int tty_fd, uint8_t* data, int buffer_size);

int writeToSerialPort(int tty_fd, const char* data);

int writeToSerialPort(int tty_fd, uint8_t byte);
