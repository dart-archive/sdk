// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_FLETCH_SRC_LOGGER_H_
#define PLATFORMS_STM_DISCO_FLETCH_SRC_LOGGER_H_

#include <stdarg.h>

class Logger;

extern Logger* logger;

class Logger {
  Logger();

 public:
  enum Level {
    LDEBUG,
    LINFO,
    LWARNING,
    LERROR,
    LFATAL,
  };

  static Logger* Create() {
    logger = new Logger();
    return logger;
  }

  void vlog(Level level, char* format, va_list args);

  void log(Level level, char* format, ...);
  void debug(char *format, ...);
  void info(char *format, ...);
  void warning(char *format, ...);
  void error(char *format, ...);
  void fatal(char *format, ...);
};

#define LOG(...) logger->log(__VA_ARGS__)
#define LOG_DEBUG(...) logger->debug(__VA_ARGS__)
#define LOG_INFO(...) logger->info(__VA_ARGS__)
#define LOG_WARNING(...) logger->warning(__VA_ARGS__)
#define LOG_ERROR(...) logger->error(__VA_ARGS__)
#define LOG_FATAL(...) logger->fatal(__VA_ARGS__)

#endif  // PLATFORMS_STM_DISCO_FLETCH_SRC_LOGGER_H_
