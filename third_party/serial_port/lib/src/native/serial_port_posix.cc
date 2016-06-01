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
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include "serial_port.h"

int selectBaudrate(int baudrate_speed){
  switch(baudrate_speed){
    // TODO baudrate 0 ? B0
    case 50: return B50; break;
    case 75: return B75; break;
    case 110: return B110; break;
    case 134: return B134; break;
    case 150: return B150; break;
    case 200: return B200; break;
    case 300: return B300; break;
    case 600: return B600; break;
    case 1200: return B1200; break;
    case 1800: return B1800; break;
    case 2400: return B2400; break;
    case 4800: return B4800; break;
    case 9600: return B9600; break;
    case 19200: return B19200; break;
    case 38400: return B38400; break;
    case 57600: return B57600; break;
    case 115200: return B115200; break;
    case 230400: return B230400; break;
    #ifdef B460800
    case 460800: return B460800;break;
    #endif
    #ifdef B500000
    case 500000: return B500000; break;
    #endif
    #ifdef B576000
    case 576000: return B576000; break;
    #endif
    #ifdef B921600
    case 921600: return B921600; break;
    #endif
    #ifdef B1000000
    case 1000000: return B1000000; break;
    #endif
    #ifdef B1152000
    case 1152000: return B1152000; break;
    #endif
    #ifdef B1500000
    case 1500000: return B1500000; break;
    #endif
    #ifdef B2000000
    case 2000000: return B2000000; break;
    #endif
    #ifdef B2500000
    case 2500000: return B2500000; break;
    #endif
    #ifdef B3000000
    case 3000000: return B3000000; break;
    #endif
    #ifdef B3500000
    case 3500000: return B3500000; break;
    #endif
    #ifdef B4000000
    case 4000000: return B4000000; break;
    #endif
    #ifdef B7200
    case 7200: return B7200; break;
    #endif
    #ifdef B14400
    case 14400: return B14400; break;
    #endif
    #ifdef B28800
    case 28800: return B28800; break;
    #endif
    #ifdef B76800
    case 76800: return B76800; break;
    #endif
    default: return -1;
  }
}

int selectDataBits(int dataBits) {
  switch (dataBits) {
    case 5: return CS5;
    case 6: return CS6;
    case 7: return CS7;
    case 8: return CS8;
    default: return -1;
  }
}

bool testSerialPort(const char* port_name){
  int tty_fd = open(port_name, O_RDWR | O_NONBLOCK);
  if (tty_fd>0){
  	close(tty_fd);
  	return true;
  }
  return false;
}

int openSerialPort(const char* port_name, int baudrate, int databits, parity_t parity, stopbits_t stopbits){
  int tty_fd = open(port_name, O_RDWR | O_NOCTTY | O_NONBLOCK);
  if(tty_fd > 0){
    struct termios tio;
    memset(&tio, 0, sizeof(tio));
    tio.c_iflag=0;
    tio.c_oflag= IGNPAR;
    tio.c_cflag &= ~CSIZE;
    tio.c_cflag &= ~(CRTSCTS);
    // TODO xon, xoff, xany
    tio.c_cflag= databits | CREAD | CLOCAL | HUPCL;
    switch(parity){
        case NONE:
            tio.c_cflag &= ~PARENB; // Clear parity enable
            break;
        case ODD:
            tio.c_cflag |= PARENB; // Parity enable
            tio.c_cflag |= PARODD; // Enable odd parity
            break;
        case EVEN:
            tio.c_cflag |= PARENB; // Parity enable
            tio.c_cflag &= ~PARODD; // Turn off odd parity = even
            break;
    }
     switch(stopbits) {
      case ONE:
        tio.c_cflag &= ~CSTOPB;
        break;
      case TWO:
        tio.c_cflag |= CSTOPB;
        break;
      }
    tio.c_lflag=0;
    tio.c_cc[VMIN]=1;
    tio.c_cc[VTIME]=0;
    cfsetospeed(&tio, baudrate);
    cfsetispeed(&tio, baudrate);
    tcflush(tty_fd, TCIFLUSH);
    tcsetattr(tty_fd, TCSANOW, &tio);
  }
  return tty_fd;
}

bool closeSerialPort(int tty_fd){
  int value = close(tty_fd);
  return value >= 0;
}

int writeToSerialPort(int tty_fd, uint8_t *data, int buffer_size){
  return write(tty_fd, data, buffer_size);
}

int readFromSerialPort(int tty_fd, uint8_t *data, int buffer_size){
  // TODO when concurrency (wait for read)
  //int8_t buffer[buffer_size];
  //fd_set readfs;
  //FD_ZERO(&readfs);
  //FD_SET(tty_fd, &readfs);
  //select(tty_fd+1, &readfs, NULL, NULL, NULL);
  //data = reinterpret_cast<uint8_t *>(malloc(buffer_size * sizeof(uint8_t)));
  return read(static_cast<int>(tty_fd), data, static_cast<int>(buffer_size));
}
