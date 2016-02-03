// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// The dart:core library for embedded dartino.
///
/// It is imported by default in all libraries.
///
/// It is the same as the mobile dartino core library without the
/// Regexp and Uri classes.
library dart.core;

import "dart:collection" show
    IterableBase,
    LinkedHashMap,
    LinkedHashSet,
    UnmodifiableListView;

import "dart:_internal" show
    CodeUnits,
    EfficientLength,
    EmptyIterable,
    ExpandIterable,
    IterableElementError,
    MappedIterable,
    SkipIterable,
    SkipWhileIterable,
    TakeIterable,
    TakeWhileIterable,
    WhereIterable,
    printToConsole,
    printToZone;

import "dart:math" show Random;  // Used by List.shuffle

import "dart:_internal" as internal show Symbol;

// TODO(sigurdm): Make dartino_compiler not depend on seeing this library. It is
// currently hard-coded to look for [ForeignMemory].
import 'dart:dartino.ffi' as not_needed; // Needed by dartino_compiler.

part "dart:_core_annotations";
part "dart:_core_bool";
part "dart:_core_comparable";
part "dart:_core_date_time";
part "dart:_core_double";
part "dart:_core_duration";
part "dart:_core_errors";
part "dart:_core_exceptions";
part "dart:_core_expando";
part "dart:_core_function";
part "dart:_core_identical";
part "dart:_core_int";
part "dart:_core_invocation";
part "dart:_core_iterable";
part "dart:_core_iterator";
part "dart:_core_list";
part "dart:_core_map";
part "dart:_core_null";
part "dart:_core_num";
part "dart:_core_object";
part "dart:_core_pattern";
part "dart:_core_print";
part "dart:_core_resource";
part "dart:_core_set";
part "dart:_core_sink";
part "dart:_core_stacktrace";
part "dart:_core_stopwatch";
part "dart:_core_string";
part "dart:_core_string_buffer";
part "dart:_core_string_sink";
part "dart:_core_symbol";
part "dart:_core_type";

/// A result from searching within a string.
///
/// A Match or an [Iterable] of Match objects is returned from [Pattern]
/// matching methods.
// TODO(sigurdm): Move this class from regex.dart to pattern.dart in the sdk.
// This is a verbatim copy from regex.dart.

abstract class Match {
  /// Returns the index in the string where the match starts.
  int get start;

  /// Returns the index in the string after the last character of the match.
  int get end;

  /// Returns the string matched by the given [group].
  ///
  /// If [group] is 0, returns the match of the pattern.
  ///
  /// The result may be `null` if the pattern didn't assign a value to it
  /// as part of this match.
  String group(int group);

  ///  Returns the string matched by the given [group].
  ///
  ///  If [group] is 0, returns the match of the pattern.
  ///
  ///  Short alias for [Match.group].
  String operator [](int group);

  /// Returns a list of the groups with the given indices.
  ///
  /// The list contains the strings returned by [group] for each index in
  /// [groupIndices].
  List<String> groups(List<int> groupIndices);

  /// Returns the number of captured groups in the match.
  ///
  /// Some patterns may capture parts of the input that was used to
  /// compute the full match. This is the number of captured groups,
  /// which is also the maximal allowed argument to the [group] method.
  int get groupCount;

  /// The string on which this match was computed.
  String get input;

  /// The pattern used to search in [input].
  Pattern get pattern;
}
