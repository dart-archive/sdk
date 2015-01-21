// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
class DateTime implements Comparable<DateTime> {
  static const int MONDAY = 1;
  static const int TUESDAY = 2;
  static const int WEDNESDAY = 3;
  static const int THURSDAY = 4;
  static const int FRIDAY = 5;
  static const int SATURDAY = 6;
  static const int SUNDAY = 7;
  static const int DAYS_PER_WEEK = 7;

  static const int JANUARY = 1;
  static const int FEBRUARY = 2;
  static const int MARCH = 3;
  static const int APRIL = 4;
  static const int MAY = 5;
  static const int JUNE = 6;
  static const int JULY = 7;
  static const int AUGUST = 8;
  static const int SEPTEMBER = 9;
  static const int OCTOBER = 10;
  static const int NOVEMBER = 11;
  static const int DECEMBER = 12;
  static const int MONTHS_PER_YEAR = 12;

  final int millisecondsSinceEpoch = 0;

  final bool isUtc = false;

  DateTime(int year,
           [int month = 1,
            int day = 1,
            int hour = 0,
            int minute = 0,
            int second = 0,
            int millisecond = 0]) {
    throw new UnimplementedError("DateTime");
  }

  DateTime.utc(int year,
               [int month = 1,
                int day = 1,
                int hour = 0,
                int minute = 0,
                int second = 0,
                int millisecond = 0]) {
    throw new UnimplementedError("DateTime.utc");
  }

  DateTime.now() {
    throw new UnimplementedError("DateTime.now");
  }

  static DateTime parse(String formattedString) {
    throw new UnimplementedError("DateTime.parse");
  }

  DateTime.fromMillisecondsSinceEpoch(int millisecondsSinceEpoch,
                                      {bool isUtc: false}) {
    throw new UnimplementedError("DateTime.fromMillisecondsSinceEpoch");
  }

  bool operator ==(other) {
    throw new UnimplementedError("DateTime.==");
  }

  bool isBefore(DateTime other) {
    return millisecondsSinceEpoch < other.millisecondsSinceEpoch;
  }

  bool isAfter(DateTime other) {
    return millisecondsSinceEpoch > other.millisecondsSinceEpoch;
  }

  bool isAtSameMomentAs(DateTime other) {
    return millisecondsSinceEpoch == other.millisecondsSinceEpoch;
  }

  int compareTo(DateTime other) {
    return millisecondsSinceEpoch.compareTo(other.millisecondsSinceEpoch);
  }

  int get hashCode => millisecondsSinceEpoch;

  DateTime toLocal() {
    throw new UnimplementedError("DateTime.toLocal");
  }

  DateTime toUtc() {
    throw new UnimplementedError("DateTime.toUtc");
  }

  String toString() {
    throw new UnimplementedError("DateTime.toString");
  }

  String toIso8601String() {
    throw new UnimplementedError("DateTime.toIso8601String");
  }

  DateTime add(Duration duration) {
    int ms = millisecondsSinceEpoch;
    return new DateTime.fromMillisecondsSinceEpoch(
        ms + duration.inMilliseconds, isUtc: isUtc);
  }

  DateTime subtract(Duration duration) {
    int ms = millisecondsSinceEpoch;
    return new DateTime.fromMillisecondsSinceEpoch(
        ms - duration.inMilliseconds, isUtc: isUtc);
  }

  Duration difference(DateTime other) {
    int ms = millisecondsSinceEpoch;
    int otherMs = other.millisecondsSinceEpoch;
    return new Duration(milliseconds: ms - otherMs);
  }

  String get timeZoneName {
    throw new UnimplementedError("DateTime.timeZoneName");
  }

  Duration get timeZoneOffset {
    throw new UnimplementedError("DateTime.timeZoneOffset");
  }

  int get year {
    throw new UnimplementedError("DateTime.year");
  }

  int get month {
    throw new UnimplementedError("DateTime.month");
  }

  int get day {
    throw new UnimplementedError("DateTime.day");
  }

  int get hour {
    throw new UnimplementedError("DateTime.hour");
  }

  int get minute {
    throw new UnimplementedError("DateTime.minute");
  }

  int get second {
    throw new UnimplementedError("DateTime.second");
  }

  int get millisecond {
    throw new UnimplementedError("DateTime.millisecond");
  }

  int get weekday {
    throw new UnimplementedError("DateTime.weekday");
  }
}

// Matches dart:core on Jan 21, 2015.
class Duration implements Comparable<DateTime> {
  static const int MICROSECONDS_PER_MILLISECOND = 1000;
  static const int MILLISECONDS_PER_SECOND = 1000;
  static const int SECONDS_PER_MINUTE = 60;
  static const int MINUTES_PER_HOUR = 60;
  static const int HOURS_PER_DAY = 24;

  static const int MICROSECONDS_PER_SECOND =
      MICROSECONDS_PER_MILLISECOND * MILLISECONDS_PER_SECOND;
  static const int MICROSECONDS_PER_MINUTE =
      MICROSECONDS_PER_SECOND * SECONDS_PER_MINUTE;
  static const int MICROSECONDS_PER_HOUR =
      MICROSECONDS_PER_MINUTE * MINUTES_PER_HOUR;
  static const int MICROSECONDS_PER_DAY =
      MICROSECONDS_PER_HOUR * HOURS_PER_DAY;

  static const int MILLISECONDS_PER_MINUTE =
      MILLISECONDS_PER_SECOND * SECONDS_PER_MINUTE;
  static const int MILLISECONDS_PER_HOUR =
      MILLISECONDS_PER_MINUTE * MINUTES_PER_HOUR;
  static const int MILLISECONDS_PER_DAY =
      MILLISECONDS_PER_HOUR * HOURS_PER_DAY;

  static const int SECONDS_PER_HOUR = SECONDS_PER_MINUTE * MINUTES_PER_HOUR;
  static const int SECONDS_PER_DAY = SECONDS_PER_HOUR * HOURS_PER_DAY;
  static const int MINUTES_PER_DAY = MINUTES_PER_HOUR * HOURS_PER_DAY;

  static const Duration ZERO = const Duration(seconds: 0);

  final int _duration;

  const Duration({int days: 0,
                  int hours: 0,
                  int minutes: 0,
                  int seconds: 0,
                  int milliseconds: 0,
                  int microseconds: 0})
      : _duration = days * MICROSECONDS_PER_DAY +
                    hours * MICROSECONDS_PER_HOUR +
                    minutes * MICROSECONDS_PER_MINUTE +
                    seconds * MICROSECONDS_PER_SECOND +
                    milliseconds * MICROSECONDS_PER_MILLISECOND +
                    microseconds;

  Duration operator +(Duration other) {
    return new Duration(microseconds: _duration + other._duration);
  }

  Duration operator -(Duration other) {
    return new Duration(microseconds: _duration - other._duration);
  }

  Duration operator *(num factor) {
    return new Duration(microseconds: (_duration * factor).round());
  }

  Duration operator ~/(int quotient) {
    return new Duration(microseconds: _duration ~/ quotient);
  }

  bool operator <(Duration other) => this._duration < other._duration;

  bool operator >(Duration other) => this._duration > other._duration;

  bool operator <=(Duration other) => this._duration <= other._duration;

  bool operator >=(Duration other) => this._duration >= other._duration;

  int get inDays => _duration ~/ Duration.MICROSECONDS_PER_DAY;

  int get inHours => _duration ~/ Duration.MICROSECONDS_PER_HOUR;

  int get inMinutes => _duration ~/ Duration.MICROSECONDS_PER_MINUTE;

  int get inSeconds => _duration ~/ Duration.MICROSECONDS_PER_SECOND;

  int get inMilliseconds => _duration ~/ Duration.MICROSECONDS_PER_MILLISECOND;

  int get inMicroseconds => _duration;

  bool operator ==(other) {
    if (other is !Duration) return false;
    return _duration == other._duration;
  }

  int get hashCode => _duration.hashCode;

  int compareTo(Duration other) => _duration.compareTo(other._duration);

  String toString() {
    throw new UnimplementedError("Duration.toString");
  }

  bool get isNegative => _duration < 0;

  Duration abs() => new Duration(microseconds: _duration.abs());

  Duration operator -() => new Duration(microseconds: -_duration);
}

// Matches dart:core on Jan 21, 2015.
class Stopwatch {
  int _start;
  int _stop;

  int get frequency => _cachedFrequency;
  bool get isRunning => _start != null && _stop == null;

  Duration get elapsed {
    throw new UnimplementedError("Stopwatch.elapsed");
  }

  int get elapsedMicroseconds => (elapsedTicks * 1000000) ~/ frequency;

  int get elapsedMilliseconds => (elapsedTicks * 1000) ~/ frequency;

  int get elapsedTicks {
    if (_start == null) return 0;
    return (_stop == null) ? (_now() - _start) : (_stop - _start);
  }

  void start() {
    if (isRunning) return;
    if (_start == null) {
      // This stopwatch has never been started.
      _start = _now();
    } else {
      // Restart this stopwatch. Prepend the elapsed time to the current
      // start time.
      _start = _now() - (_stop - _start);
      _stop = null;
    }
  }

  void stop() {
    if (!isRunning) return;
    _stop = _now();
  }

  void reset() {
    throw new UnimplementedError("Stopwatch.reset");
  }

  static final int _cachedFrequency = _frequency();
  static int _frequency() native;
  static int _now() native;
}
