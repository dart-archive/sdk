// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_LOGGER_H_
#define SRC_LOGGER_H_

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
#define DEBUG_LOG(...) logger->debug(__VA_ARGS__)
#define INFO_LOG(...) logger->info(__VA_ARGS__)
#define WARNING_LOG(...) logger->warning(__VA_ARGS__)
#define ERROR_LOG(...) logger->error(__VA_ARGS__)
#define FATAL_LOG(...) logger->fatal(__VA_ARGS__)

#endif  // SRC_LOGGER_H_
