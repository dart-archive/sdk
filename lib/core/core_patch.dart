// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.core_patch;

import 'dart:_fletch_system' as fletch;

part 'double.dart';
part 'int.dart';
part 'string.dart';

const patch = "patch";

@patch external bool identical(Object a, Object b);

@patch int identityHashCode(Object object) => _identityHashCode(object);

@fletch.native external _identityHashCode(Object object);

@patch class Object {
  @patch String toString() => '[object Object]';

  @patch int get hashCode => _identityHashCode(this);

  @patch noSuchMethod(Invocation invocation) {
    // TODO(kasperl): Extract information from the invocation
    // so we can construct the right NoSuchMethodError.
    fletch.unresolved("<unknown>");
  }

  // The noSuchMethod helper is automatically called from the
  // trampoline and it is passed the selector. The arguments
  // to the original call are still present on the stack, so
  // it is possible to dig them out if need be.
  _noSuchMethod(selector) => noSuchMethod(null);

  // The noSuchMethod trampoline is automatically generated
  // by the compiler. It calls the noSuchMethod helper and
  // takes care off removing an arbitrary number of arguments
  // from the caller stack before it returns.
  external _noSuchMethodTrampoline();
}

@patch class Function {
  @patch static apply(Function function,
                      List positionalArguments,
                      [Map<Symbol, dynamic> namedArguments]) {
    int arity = positionalArguments.length;
    if (arity > 2 || namedArguments != null) {
      throw new UnimplementedError("Function.apply");
    }
    switch (arity) {
      case 0: return function();
      case 1: return function(positionalArguments[0]);
      case 2: return function(positionalArguments[0], positionalArguments[1]);
      default:
        throw new UnimplementedError("Function.apply");
    }
  }
}

@patch class bool {
  @patch factory bool.fromEnvironment(
      String name,
      {bool defaultValue: false}) => defaultValue;
}

@patch class String {
  @patch factory String.fromCharCodes(
      Iterable<int> charCode,
      [int start,
       int end]) = _StringImpl.fromCharCodes;

  @patch factory String.fromCharCode(int charCode) = _StringImpl.fromCharCode;

  @patch factory String.fromEnvironment(
      String name,
      {String defaultValue}) => defaultValue;
}

@patch class StringBuffer {
  final List<String> _strings = [];
  int _length = 0;

  @patch StringBuffer([String contents = ""]) {
    write(contents);
  }

  @patch void write(Object obj) {
    String str = obj.toString();
    if (str is! String) throw new ArgumentError(obj);
    int length = str.length;
    if (length > 0) {
      _strings.add(str);
      _length += length;
    }
  }

  @patch void writeAll(Iterable objects, [String separator = ""]) {
    bool first = true;
    for (var obj in objects) {
      if (first) {
        first = false;
      } else {
        write(separator);
      }
      write(obj);
    }
  }

  @patch void writeCharCode(int charCode) {
    String char = new String.fromCharCode(charCode);
    _strings.add(char);
    _length += char.length;
  }

  @patch void clear() {
    _strings.clear();
    _length = 0;
  }

  @patch int get length => _length;

  @patch String toString() {
    _StringImpl result = _StringImpl._create(length);
    int offset = 0;
    int count = _strings.length;
    for (int i = 0; i < count; i++) {
      String str = _strings[i];
      int length = str.length;
      // TODO(ajohnsen): Create a native '_setStringContent' to speed it up.
      for (int j = 0; j < length; j++) {
        result._setCodeUnitAt(offset + j, str.codeUnitAt(j));
      }
      offset += length;
    }
    return result;
  }
}

@patch class Error {
  @patch static String _stringToSafeString(String string) {
    throw "_stringToSafeString is unimplemented";
  }

  @patch static String _objectToString(Object object) {
    if (identical(object, null) ||
        identical(object, true) ||
        identical(object, false) ||
        object is num ||
        object is String) {
      return object.toString();
    }
    return '[object Object]';
  }

  @patch StackTrace get stackTrace {
    throw "getter stackTrace is unimplemented";
  }
}

@patch class Stopwatch {
  @patch @fletch.native external static int _now();

  @patch static int _initTicker() {
    _frequency = _fletchNative_frequency();
  }

  @fletch.native external static int _fletchNative_frequency();
}

@patch class List {
  @patch factory List([int length]) {
    return fletch.newList(length);
  }

  @patch factory List.filled(int length, E fill) {
    // All error handling on the length parameter is done at the implementation
    // of new _List.
    var result = fletch.newList(length);
    if (fill != null) {
      for (int i = 0; i < length; i++) {
        result[i] = fill;
      }
    }
    return result;
  }

  @patch factory List.from(Iterable elements, {bool growable: true}) {
    // TODO(ajohnsen): elements.length can be slow if not a List. Consider
    // fast-path non-list & growable, and create internal helper for non-list &
    // non-growable.
    int length = elements.length;
    var list;
    if (growable) {
      list = fletch.newList(null);
      list.length = length;
    } else {
      list = fletch.newList(length);
    }
    if (elements is List) {
      for (int i = 0; i < length; i++) {
        list[i] = elements[i];
      }
    } else {
      int i = 0;
      elements.forEach((e) { list[i++] = e; });
    }
    return list;
  }
}

@patch class NoSuchMethodError {
  @patch String toString() {
    return "NoSuchMethodError: '$_memberName'";
  }
}

@patch class Null {
  // This function is overridden, so we can bypass the 'this == null' check.
  bool operator ==(other) => other == null;
}

@patch class int {
  @patch static int parse(
      String source,
      {int radix,
       int onError(String source)}) {
    source = source.trim();
    if (source.isEmpty) {
      if (onError != null) return onError(source);
      throw new FormatException("Can't parse string as integer", source);
    }
    if (radix == null) {
      if (source.startsWith('0x') ||
          source.startsWith('-0x') ||
          source.startsWith('+0x')) {
        radix = 16;
      } else {
        radix = 10;
      }
    } else if (radix == 16) {
      if (source.startsWith('0x') ||
          source.startsWith('-0x') ||
          source.startsWith('+0x')) {
        if (onError != null) return onError(source);
        throw new FormatException("Can't parse string as integer", source);
      }
    } else {
      if (radix < 2 || radix > 36) throw new ArgumentError(radix);
    }
    return _parse(source, radix, onError);
  }

  @fletch.native static int _parse(
      String source,
      int radix,
      int onError(String source)) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError(source);
      case fletch.indexOutOfBounds:
        if (onError != null) return onError(source);
        throw new FormatException("Can't parse string as integer", source);
    }
  }

  @patch factory int.fromEnvironment(
      String name,
      {int defaultValue}) => defaultValue;
}

@patch class double {
  @patch static double parse(String source, [double onError(String source)]) {
    return _parse(source.trim(), onError);
  }

  @fletch.native static double _parse(
      String source,
      double onError(String source)) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError(source);
      case fletch.indexOutOfBounds:
        if (onError != null) return onError(source);
        throw new FormatException("Can't parse string as double", source);
    }
  }
}

@patch class DateTime {
  static const _MILLISECOND_INDEX = 0;
  static const _SECOND_INDEX = 1;
  static const _MINUTE_INDEX = 2;
  static const _HOUR_INDEX = 3;
  static const _DAY_INDEX = 4;
  static const _WEEKDAY_INDEX = 5;
  static const _MONTH_INDEX = 6;
  static const _YEAR_INDEX = 7;

  List __parts;

  @patch DateTime._internal(int year,
                            int month,
                            int day,
                            int hour,
                            int minute,
                            int second,
                            int millisecond,
                            bool isUtc)
      : this.isUtc = isUtc,
        this.millisecondsSinceEpoch = _brokenDownDateToMillisecondsSinceEpoch(
            year, month, day, hour, minute, second, millisecond, isUtc) {
    if (millisecondsSinceEpoch == null) throw new ArgumentError();
    if (isUtc == null) throw new ArgumentError();
  }

  @patch DateTime._now()
      : isUtc = false,
        millisecondsSinceEpoch = _getCurrentMs();

  @patch String get timeZoneName {
    if (isUtc) return "UTC";
    return _timeZoneName(millisecondsSinceEpoch);
  }

  @patch Duration get timeZoneOffset {
    if (isUtc) return new Duration();
    int offsetInSeconds = _timeZoneOffsetInSeconds(millisecondsSinceEpoch);
    return new Duration(seconds: offsetInSeconds);
  }

  /** The first list contains the days until each month in non-leap years. The
    * second list contains the days in leap years. */
  static const List<List<int>> _DAYS_UNTIL_MONTH =
      const [const [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334],
             const [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]];

  static List _computeUpperPart(int localMs) {
    final int DAYS_IN_4_YEARS = 4 * 365 + 1;
    final int DAYS_IN_100_YEARS = 25 * DAYS_IN_4_YEARS - 1;
    final int DAYS_IN_400_YEARS = 4 * DAYS_IN_100_YEARS + 1;
    final int DAYS_1970_TO_2000 = 30 * 365 + 7;
    final int DAYS_OFFSET = 1000 * DAYS_IN_400_YEARS + 5 * DAYS_IN_400_YEARS -
                            DAYS_1970_TO_2000;
    final int YEARS_OFFSET = 400000;

    int resultYear = 0;
    int resultMonth = 0;
    int resultDay = 0;

    // Always round down.
    final int daysSince1970 = _flooredDivision(localMs,
                                               Duration.MILLISECONDS_PER_DAY);
    int days = daysSince1970;
    days += DAYS_OFFSET;
    resultYear = 400 * (days ~/ DAYS_IN_400_YEARS) - YEARS_OFFSET;
    days = days.remainder(DAYS_IN_400_YEARS);
    days--;
    int yd1 = days ~/ DAYS_IN_100_YEARS;
    days = days.remainder(DAYS_IN_100_YEARS);
    resultYear += 100 * yd1;
    days++;
    int yd2 = days ~/ DAYS_IN_4_YEARS;
    days = days.remainder(DAYS_IN_4_YEARS);
    resultYear += 4 * yd2;
    days--;
    int yd3 = days ~/ 365;
    days = days.remainder(365);
    resultYear += yd3;

    bool isLeap = (yd1 == 0 || yd2 != 0) && yd3 == 0;
    if (isLeap) days++;

    List<int> daysUntilMonth = _DAYS_UNTIL_MONTH[isLeap ? 1 : 0];
    for (resultMonth = 12;
         daysUntilMonth[resultMonth - 1] > days;
         resultMonth--) {
      // Do nothing.
    }
    resultDay = days - daysUntilMonth[resultMonth - 1] + 1;

    int resultMillisecond = localMs % Duration.MILLISECONDS_PER_SECOND;
    int resultSecond =
        _flooredDivision(localMs, Duration.MILLISECONDS_PER_SECOND) %
            Duration.SECONDS_PER_MINUTE;

    int resultMinute = _flooredDivision(localMs,
                                        Duration.MILLISECONDS_PER_MINUTE);
    resultMinute %= Duration.MINUTES_PER_HOUR;

    int resultHour = _flooredDivision(localMs, Duration.MILLISECONDS_PER_HOUR);
    resultHour %= Duration.HOURS_PER_DAY;

    // In accordance with ISO 8601 a week
    // starts with Monday. Monday has the value 1 up to Sunday with 7.
    // 1970-1-1 was a Thursday.
    int resultWeekday = ((daysSince1970 + DateTime.THURSDAY - DateTime.MONDAY) %
          DateTime.DAYS_PER_WEEK) + DateTime.MONDAY;

    List list = new List(_YEAR_INDEX + 1);
    list[_MILLISECOND_INDEX] = resultMillisecond;
    list[_SECOND_INDEX] = resultSecond;
    list[_MINUTE_INDEX] = resultMinute;
    list[_HOUR_INDEX] = resultHour;
    list[_DAY_INDEX] = resultDay;
    list[_WEEKDAY_INDEX] = resultWeekday;
    list[_MONTH_INDEX] = resultMonth;
    list[_YEAR_INDEX] = resultYear;
    return list;
  }

  get _parts {
    if (__parts == null) {
      __parts = _computeUpperPart(_localDateInUtcMs);
    }
    return __parts;
  }

  @patch int get millisecond => _parts[_MILLISECOND_INDEX];

  @patch int get second => _parts[_SECOND_INDEX];

  @patch int get minute => _parts[_MINUTE_INDEX];

  @patch int get hour => _parts[_HOUR_INDEX];

  @patch int get day => _parts[_DAY_INDEX];

  @patch int get weekday => _parts[_WEEKDAY_INDEX];

  @patch int get month => _parts[_MONTH_INDEX];

  @patch int get year => _parts[_YEAR_INDEX];

  /**
   * Returns the amount of milliseconds in UTC that represent the same values
   * as [this].
   *
   * Say [:t:] is the result of this function, then
   * * [:this.year == new DateTime.fromMillisecondsSinceEpoch(t, true).year:],
   * * [:this.month == new DateTime.fromMillisecondsSinceEpoch(t, true).month:],
   * * [:this.day == new DateTime.fromMillisecondsSinceEpoch(t, true).day:],
   * * [:this.hour == new DateTime.fromMillisecondsSinceEpoch(t, true).hour:],
   * * ...
   *
   * Daylight savings is computed as if the date was computed in [1970..2037].
   * If [this] lies outside this range then it is a year with similar
   * properties (leap year, weekdays) is used instead.
   */
  int get _localDateInUtcMs {
    int ms = millisecondsSinceEpoch;
    if (isUtc) return ms;
    int offset =
        _timeZoneOffsetInSeconds(ms) * Duration.MILLISECONDS_PER_SECOND;
    return ms + offset;
  }

  static int _flooredDivision(int a, int b) {
    return (a - (a < 0 ? b - 1 : 0)) ~/ b;
  }

  // Returns the days since 1970 for the start of the given [year].
  // [year] may be before epoch.
  static int _dayFromYear(int year) {
    return 365 * (year - 1970)
            + _flooredDivision(year - 1969, 4)
            - _flooredDivision(year - 1901, 100)
            + _flooredDivision(year - 1601, 400);
  }

  static bool _isLeapYear(y) {
    // (y % 16 == 0) matches multiples of 400, and is faster than % 400.
    return (y % 4 == 0) && ((y % 16 == 0) || (y % 100 != 0));
  }

  @patch static int _brokenDownDateToMillisecondsSinceEpoch(
      int year, int month, int day,
      int hour, int minute, int second, int millisecond,
      bool isUtc) {
    // Simplify calculations by working with zero-based month.
    --month;
    // Deal with under and overflow.
    if (month >= 12) {
      year += month ~/ 12;
      month = month % 12;
    } else if (month < 0) {
      int realMonth = month % 12;
      year += (month - realMonth) ~/ 12;
      month = realMonth;
    }

    // First compute the seconds in UTC, independent of the [isUtc] flag. If
    // necessary we will add the time-zone offset later on.
    int days = day - 1;
    days += _DAYS_UNTIL_MONTH[_isLeapYear(year) ? 1 : 0][month];
    days += _dayFromYear(year);
    int millisecondsSinceEpoch =
        days   * Duration.MILLISECONDS_PER_DAY    +
        hour   * Duration.MILLISECONDS_PER_HOUR   +
        minute * Duration.MILLISECONDS_PER_MINUTE +
        second * Duration.MILLISECONDS_PER_SECOND +
        millisecond;

    // Since [_timeZoneOffsetInSeconds] will crash if the input is far out of
    // the valid range we do a preliminary test that weeds out values that can
    // not become valid even with timezone adjustments.
    // The timezone adjustment is always less than a day, so adding a security
    // margin of one day should be enough.
    if (millisecondsSinceEpoch.abs() >
        (_MAX_MILLISECONDS_SINCE_EPOCH + Duration.MILLISECONDS_PER_DAY)) {
      return null;
    }

    if (!isUtc) {
      // Note that we need to remove the local timezone adjustement before
      // asking for the correct zone offset.
      int adjustment = _localTimeZoneOffset() *
          Duration.MILLISECONDS_PER_SECOND;
      int zoneOffset =
          _timeZoneOffsetInSeconds(millisecondsSinceEpoch - adjustment);
      millisecondsSinceEpoch -= zoneOffset * Duration.MILLISECONDS_PER_SECOND;
    }
    if (millisecondsSinceEpoch.abs() > _MAX_MILLISECONDS_SINCE_EPOCH) {
      return null;
    }
    return millisecondsSinceEpoch;
  }

  static int _weekDay(y) {
    // 1/1/1970 was a Thursday.
    return (_dayFromYear(y) + 4) % 7;
  }

  /**
   * Returns a year in the range 2008-2035 matching
   * * leap year, and
   * * week day of first day.
   *
   * Leap seconds are ignored.
   * Adapted from V8's date implementation. See ECMA 262 - 15.9.1.9.
   */
  static int _equivalentYear(int year) {
    // Returns the week day (in range 0 - 6).
    // 1/1/1956 was a Sunday (i.e. weekday 0). 1956 was a leap-year.
    // 1/1/1967 was a Sunday (i.e. weekday 0).
    // Without leap years a subsequent year has a week day + 1 (for example
    // 1/1/1968 was a Monday). With leap-years it jumps over one week day
    // (e.g. 1/1/1957 was a Tuesday).
    // After 12 years the weekdays have advanced by 12 days + 3 leap days =
    // 15 days. 15 % 7 = 1. So after 12 years the week day has always
    // (now independently of leap-years) advanced by one.
    // weekDay * 12 gives thus a year starting with the wanted weekDay.
    int recentYear = (_isLeapYear(year) ? 1956 : 1967) + (_weekDay(year) * 12);
    // Close to the year 2008 the calendar cycles every 4 * 7 years (4 for the
    // leap years, 7 for the weekdays).
    // Find the year in the range 2008..2037 that is equivalent mod 28.
    return 2008 + (recentYear - 2008) % 28;
  }

  /**
   * Returns the UTC year for the corresponding [secondsSinceEpoch].
   * It is relatively fast for values in the range 0 to year 2098.
   *
   * Code is adapted from V8.
   */
  static int _yearsFromSecondsSinceEpoch(int secondsSinceEpoch) {
    final int DAYS_IN_4_YEARS = 4 * 365 + 1;
    final int DAYS_IN_100_YEARS = 25 * DAYS_IN_4_YEARS - 1;
    final int DAYS_YEAR_2098 = DAYS_IN_100_YEARS + 6 * DAYS_IN_4_YEARS;

    int days = secondsSinceEpoch ~/ Duration.SECONDS_PER_DAY;
    if (days > 0 && days < DAYS_YEAR_2098) {
      // According to V8 this fast case works for dates from 1970 to 2099.
      return 1970 + (4 * days + 2) ~/ DAYS_IN_4_YEARS;
    }
    int ms = secondsSinceEpoch * Duration.MILLISECONDS_PER_SECOND;
    return _computeUpperPart(ms)[_YEAR_INDEX];
  }

  /**
   * Returns a date in seconds that is equivalent to the current date. An
   * equivalent date has the same fields ([:month:], [:day:], etc.) as the
   * [this], but the [:year:] is in the range [1970..2037].
   *
   * * The time since the beginning of the year is the same.
   * * If [this] is in a leap year then the returned seconds are in a leap
   *   year, too.
   * * The week day of [this] is the same as the one for the returned date.
   */
  static int _equivalentSeconds(int millisecondsSinceEpoch) {
    final int CUT_OFF_SECONDS = 2100000000;

    int secondsSinceEpoch = _flooredDivision(millisecondsSinceEpoch,
                                             Duration.MILLISECONDS_PER_SECOND);

    if (secondsSinceEpoch < 0 || secondsSinceEpoch >= CUT_OFF_SECONDS) {
      int year = _yearsFromSecondsSinceEpoch(secondsSinceEpoch);
      int days = _dayFromYear(year);
      int equivalentYear = _equivalentYear(year);
      int equivalentDays = _dayFromYear(equivalentYear);
      int diffDays = equivalentDays - days;
      secondsSinceEpoch += diffDays * Duration.SECONDS_PER_DAY;
    }
    return secondsSinceEpoch;
  }

  static int _timeZoneOffsetInSeconds(int millisecondsSinceEpoch) {
    int equivalentSeconds = _equivalentSeconds(millisecondsSinceEpoch);
    return _timeZoneOffset(equivalentSeconds);
  }

  static String _timeZoneName(int millisecondsSinceEpoch) {
    int equivalentSeconds = _equivalentSeconds(millisecondsSinceEpoch);
    return _timeZone(equivalentSeconds);
  }

  @fletch.native external static int _getCurrentMs();

  @fletch.native external static String _timeZone(int clampedSecondsSinceEpoch);

  @fletch.native external static int _timeZoneOffset(
      int clampedSecondsSinceEpoch);

  @fletch.native external static int _localTimeZoneOffset();
}

class Thread {

  // We keep track of the top of the coroutine stack and
  // the list of other threads that are waiting for this
  // thread to exit.
  Coroutine _coroutine;
  List<Thread> _joiners;

  // When a thread exits, we keep the result of running
  // its code around so we can return to other threads
  // that join it.
  bool _isDone = false;
  var _result;

  // The ready threads are linked together.
  Thread _previous;
  Thread _next;

  static Thread _current = new Thread._initial();
  static Thread _idleThreads;

  // This static is initialized as part of creating the
  // initial thread. This way we can avoid checking for
  // lazy initialization for it.
  static Coroutine _scheduler;

  Thread._initial() {
    _previous = this;
    _next = this;
    _scheduler = new Coroutine(_schedulerLoop);
  }

  Thread._forked(entry) {
    _coroutine = new Coroutine((ignore) {
      fletch.runToEnd(entry);
    });
  }

  static Thread get current => _current;

  static Thread fork(entry) {
    _current;  // Force initialization of threading system.
    Thread thread = new Thread._forked(entry);
    _markReady(thread);
    return thread;
  }

  static void yield() {
    _current._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(_scheduler, _current._next);
  }

  static void exit([value]) {
    // If we never needed the scheduler coroutine, we can just
    // go ahead and halt now.
    if (_scheduler == null) fletch.halt(0);

    Thread thread = _current;
    List<Thread> joiners = thread._joiners;
    if (joiners != null) {
      for (Thread joiner in joiners) _resumeThread(joiner);
      joiners.clear();
    }

    thread._isDone = true;
    thread._result = value;

    // Suspend the current thread. It will never wake up again.
    Thread next = _suspendThread(thread, true);
    thread._coroutine = null;
    fletch.coroutineChange(Thread._scheduler, next);
  }

  join() {
    // If the thread is already done, we just return the result.
    if (_isDone) return _result;

    // Add the current thread to the list of threads waiting
    // to join [this] thread.
    Thread thread = _current;
    if (_joiners == null) {
      _joiners = [ thread ];
    } else {
      _joiners.add(thread);
    }

    // Suspend the current thread and change to the scheduler.
    // When we get back, the [this] thread has exited and we
    // can go ahead and return the result.
    Thread next = _suspendThread(thread, false);
    thread._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(Thread._scheduler, next);
    return _result;
  }

  static void _resumeThread(Thread thread) {
    _idleThreads = _unlink(thread);
    _markReady(thread);
  }

  static void _markReady(Thread thread) {
    _current = _link(thread, _current);
  }

  static Thread _link(Thread thread, Thread list) {
    if (list == null) {
      thread._next = thread;
      thread._previous = thread;
      return thread;
    }

    Thread next = list._next;
    list._next = thread;
    next._previous = thread;
    thread._previous = list;
    thread._next = next;
    return list;
  }

  static Thread _unlink(Thread thread) {
    Thread next = thread._next;
    if (identical(thread, next)) {
      return null;
    }

    Thread previous = thread._previous;
    previous._next = next;
    next._previous = previous;
    return next;
  }

  static Thread _suspendThread(Thread thread, bool exiting) {
    Thread current = _current = _unlink(thread);

    if (exiting) {
      thread._next = null;
      thread._previous = null;
    } else {
      _idleThreads = _link(thread, _idleThreads);
    }

    if (current != null) return current;

    // If we don't have any idle threads, halt.
    if (exiting && _idleThreads == null) fletch.halt(0);

    while (true) {
      Process._handleMessages();
      // A call to _handleMessages can handle more messages than signaled, so
      // we can get a following false-positive wakeup. If no new _current is
      // set, simply yield again.
      current = _current;
      if (current != null) return current;
      fletch.yield(false);
    }
  }

  static void _yieldTo(Thread from, Thread to) {
    from._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(_scheduler, to);
  }

  // TODO(kasperl): This is temporary debugging support. We
  // should probably replace this support for passing in an
  // id of some sort when forking a thread.
  static int _count = 0;
  int _index = _count++;
  toString() => "thread:$_index";

  // TODO(kasperl): Right now, we ignore the events -- and they
  // are always null -- but it is easy to imagine using the
  // events to communicate things to the scheduler.
  static void _schedulerLoop(next) {
    while (true) {
      // Update the current thread to the next one and change to
      // its coroutine. In return, the scheduled thread determines
      // which thread to schedule next.
      _current = next;
      next = fletch.coroutineChange(next._coroutine, null);
    }
  }
}

class Coroutine {

  // TODO(kasperl): The VM has assumptions about the layout
  // of coroutine fields. We should validate that the code
  // agrees with those assumptions.
  var _stack;
  var _caller;

  Coroutine(entry) {
    _stack = _coroutineNewStack(this, entry);
  }

  bool get isSuspended => identical(_caller, null);
  bool get isRunning => !isSuspended && !isDone;
  bool get isDone => identical(_caller, this);

  call(argument) {
    if (!isSuspended) throw "Cannot call non-suspended coroutine";
    _caller = _coroutineCurrent();
    var result = fletch.coroutineChange(this, argument);

    // If the called coroutine is done now, we clear the
    // stack reference in it so the memory can be reclaimed.
    if (isDone) {
      _stack = null;
    } else {
      _caller = null;
    }
    return result;
  }

  static yield(value) {
    Coroutine caller = _coroutineCurrent()._caller;
    if (caller == null) throw "Cannot yield outside coroutine";
    return fletch.coroutineChange(caller, value);
  }

  _coroutineStart(entry) {
    // The first call to changeStack is actually skipped but we need
    // it to make sure the newly started coroutine is suspended in
    // exactly the same way as we do when yielding.
    var argument = fletch.coroutineChange(0, 0);
    var result = entry(argument);

    // Mark this coroutine as done and change back to the caller.
    Coroutine caller = _caller;
    _caller = this;
    fletch.coroutineChange(caller, result);
  }

  @fletch.native external static _coroutineCurrent();
  @fletch.native external static _coroutineNewStack(coroutine, entry);
}

class Process {
  /**
   * Spawn a top-level function.
   */
  static void spawn(Function fn, [argument]) {
    _spawn(_entry, fn, argument);
  }

  /**
   * Divide the elements in [arguments] into a matching number of processes
   * with [fn] as entry. The current process blocks until all processes have
   * terminated.
   *
   * The elements in [arguments] can be any immutable (see [isImmutable])
   * object.
   *
   * The function [fn] must be a top-level or static function.
   */
  static List divide(fn(argument), List arguments) {
    // TODO(ajohnsen): Type check arguments.
    int length = arguments.length;
    List channels = new List(length);
    for (int i = 0; i < length; i++) {
      channels[i] = new Channel();
    }
    _divide(_entryDivide, fn, channels, arguments);
    for (int i = 0; i < length; i++) {
      channels[i] = channels[i].receive();
    }
    return channels;
  }

  /**
   * Exit the current process. If a non-null [to] port is provided,
   * the process will send the provided [value] to the [to] port as
   * its final action.
   */
  static void exit({value, Port to}) {
    try {
      if (to != null) to._sendExit(value);
    } finally {
      fletch.yield(true);
    }
  }

  // Low-level entry for spawned processes.
  static void _entry(fn, argument) {
    if (argument == null) {
      fletch.runToEnd(fn);
    } else {
      fletch.runToEnd(() => fn(argument));
    }
  }

  // Low-level helper function for spawning.
  @fletch.native static void _spawn(Function entry, Function fn, argument) {
    throw new ArgumentError();
  }

  // Low-level entry for dividing processes.
  static void _entryDivide(fn, port, argument) {
    try {
      Process.exit(value: fn(argument), to: port);
    } finally {
      // TODO(ajohnsen): Handle exceptions?
      Process.exit(to: port);
    }
  }

  // Low-level helper function for dividing.
  @fletch.native static _divide(
      Function entry,
      Function fn,
      List<Port> ports,
      List arguments) {
    for (int i = 0; i < arguments.length; i++) {
      if (!isImmutable(arguments[i])) {
        throw new ArgumentError.value(
            arguments[i], "@$i", "Cannot pass mutable data");
      }
    }
    throw new ArgumentError.value(fn, "fn", "Entry function must be static");
  }

  static void _handleMessages() {
    Channel channel;
    while ((channel = _queueGetChannel()) != null) {
      var message = _queueGetMessage();
      channel.send(message);
    }
  }

  @fletch.native external static _queueGetMessage();
  @fletch.native external static Channel _queueGetChannel();
}

// The port list sentinel is sent as a prefix to the sequence
// of messages sent using [Port.sendMultiple].
class _PortListSentinel {
  const _PortListSentinel();
}

const _portListSentinel = const _PortListSentinel();

// Ports allow you to send messages to a channel. Ports are
// are transferable and can be sent between processes.
class Port {
  int _port;
  Port(Channel channel) {
    _port = _create(channel, this);
  }

  // TODO(kasperl): Temporary debugging aid.
  int get id => _port;

  // Send a message to the channel. Not blocking.
  @fletch.native void send(message) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError();
      case fletch.illegalState:
        throw new StateError("Port is closed.");
      default:
        throw fletch.nativeError;
    }
  }

  // Send multiple messages to the channel. Not blocking.
  void sendMultiple(Iterable iterable) {
    _sendList(iterable.toList(growable: true), _portListSentinel);
  }

  @fletch.native void _sendList(List list, sentinel) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError();
      case fletch.illegalState:
        throw new StateError("Port is closed.");
      default:
        throw fletch.nativeError;
    }
  }

  @fletch.native void _sendExit(value) {
    throw new StateError("Port is closed.");
  }

  // Close the port. Messages already sent to a port will still
  // be delivered to the corresponding channel.
  void close() {
    int port = _port;
    if (port == 0) throw new StateError("Port already closed.");
    _port = 0;
    _close(port, this);
  }

  @fletch.native external static int _create(Channel channel, Port port);
  @fletch.native external static void _close(int port, Port portObject);
  @fletch.native external static void _incrementRef(int port);
}

class Channel {
  Thread _receiver;  // TODO(kasperl): Should this be a queue too?

  // TODO(kasperl): Maybe make this a bit smarter and store
  // the elements in a growable list? Consider allowing bounds
  // on the queue size.
  _ChannelEntry _head;
  _ChannelEntry _tail;

  // Deliver the message synchronously. If the receiver
  // isn't ready to receive yet, the sender blocks.
  void deliver(message) {
    Thread sender = Thread._current;
    _enqueue(new _ChannelEntry(message, sender));
    Thread next = Thread._suspendThread(sender, false);
    // TODO(kasperl): Should we yield to receiver if possible?
    Thread._yieldTo(sender, next);
  }

  // Send a message to the channel. Not blocking.
  void send(message) {
    _enqueue(new _ChannelEntry(message, null));
  }

  // Receive a message. If no messages are available
  // the receiver blocks.
  receive() {
    if (_receiver != null) {
      throw new StateError("Channel cannot have multiple receivers (yet).");
    }

    if (_head == null) {
      Thread receiver = Thread._current;
      _receiver = receiver;
      Thread next = Thread._suspendThread(receiver, false);
      Thread._yieldTo(receiver, next);
    }

    var result = _dequeue();
    if (identical(result, _portListSentinel)) {
      int length = _dequeue();
      result = new List(length);
      for (int i = 0; i < length; i++) result[i] = _dequeue();
    }
    return result;
  }

  _enqueue(_ChannelEntry entry) {
    if (_tail == null) {
      _head = _tail = entry;
    } else {
      _tail = _tail.next = entry;
    }

    // Signal the receiver (if any).
    Thread receiver = _receiver;
    if (receiver != null) {
      _receiver = null;
      Thread._resumeThread(receiver);
    }
  }

  _dequeue() {
    _ChannelEntry entry = _head;
    _ChannelEntry next = entry.next;
    _head = next;
    if (next == null) _tail = next;
    Thread sender = entry.sender;
    if (sender != null) Thread._resumeThread(sender);
    return entry.message;
  }
}

class _ChannelEntry {
  final message;
  final Thread sender;
  _ChannelEntry next;
  _ChannelEntry(this.message, this.sender);
}

bool isImmutable(Object object) => _isImmutable(object);

@fletch.native external bool _isImmutable(String string);
