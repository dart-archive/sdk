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

#include <io.h>
#include <fcntl.h>
#include <stdio.h>
#include <windows.h>
#include "serial_port.h"

int selectBaudrate(int baudrate_speed){
  if(baudrate_speed<0){
    return -1;
  }
  return baudrate_speed;
}

int selectDataBits(int databits_nb) {
  switch(databits_nb){
    case 5:
      return DATABITS_5;
    case 6:
      return DATABITS_6;
    case 7:
      return DATABITS_7;
    case 8:
      return DATABITS_8;
    default:
      return -1;
  }
}

bool testSerialPort(const char* port_name){
  HANDLE handlePort = CreateFile(port_name, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING,  0, NULL);
  if(handlePort == INVALID_HANDLE_VALUE){
     return false;
  }
  CloseHandle(handlePort);
  return true;
}

int convertParity(parity_t parity){
    // MARKPARITY, SPACEPARITY not supported
    switch(parity){
        default:
        case NONE:
            return NOPARITY;
         case ODD:
            return ODDPARITY;
         case EVEN:
            return EVENPARITY;
    }
}

int convertStopBits(stopbits_t stopbits){
    switch(stopbits){
        default:
        case ONE:
            return ONESTOPBIT;
         case TWO:
            return TWOSTOPBITS;
            /*
         case TWOSTOPBITS:
            return TWOSTOPBITS;
            */
    }
}

int openSerialPort(const char* port_name, int baudrate, int databits, parity_t parity, stopbits_t stopbits){
  HANDLE handlePort = CreateFile(port_name, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
  int tty_fd = _open_osfhandle(reinterpret_cast<intptr_t>(handlePort), _O_TEXT);
  if(tty_fd > 0){
    DCB config = {0};
    config.DCBlength = sizeof(config);
    config.fBinary = true;
    config.BaudRate = baudrate;
    config.ByteSize = databits;
    config.Parity = convertParity(parity);
    config.StopBits = convertStopBits(stopbits);
    config.fDtrControl = 0;
    config.fRtsControl = 0;
    SetCommState(handlePort, &config);

    COMMTIMEOUTS commTimeouts = {0};
    commTimeouts.ReadIntervalTimeout = 1;
    commTimeouts.ReadTotalTimeoutMultiplier  = 0;
    commTimeouts.ReadTotalTimeoutConstant    = 1000;
    commTimeouts.WriteTotalTimeoutConstant   = 1000;
    commTimeouts.WriteTotalTimeoutMultiplier = 1;
    SetCommTimeouts(handlePort, &commTimeouts);

    PurgeComm(handlePort, PURGE_RXCLEAR);
    PurgeComm(handlePort, PURGE_TXCLEAR);
  }
  return tty_fd;
}

bool closeSerialPort(int tty_fd){
  HANDLE handlePort =  reinterpret_cast<HANDLE>(_get_osfhandle(tty_fd));
  return CloseHandle(handlePort);
}

int readFromSerialPort(int tty_fd, uint8_t* data, int buffer_size){
  DWORD bytes_read = -1;
  HANDLE handlePort =  reinterpret_cast<HANDLE>(_get_osfhandle(tty_fd));
  ReadFile(handlePort, data, buffer_size, &bytes_read, NULL);
  return bytes_read;
}

int writeToSerialPort(int tty_fd, uint8_t* data, int buffer_size){
  HANDLE handlePort =  reinterpret_cast<HANDLE>(_get_osfhandle(tty_fd));
  DWORD length = -1;
  WriteFile(handlePort, data, buffer_size, &length, NULL);
  return length;
}
