// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library servicec.util;

const String validIdentifier =
    "A valid identifier contains only alphanumeric characters and " +
    "underscores, and does not start with a digit.";

/// Takes a [camelize]d string and reverses the camelization: each capital case
/// is considered to be the start of a word; each word is lowered and words are
/// joined together by underscores. Existing underscores are preserved, and if
/// they already separate words, no additional underscores are added (e.g.
/// "HelloWorld" and "Hello_World" both become "hello_world").
///
/// Throws an [ArgumentError] if the input is not a valid identifier.
String underscore(String text) {
  if (!isValidIdentifier(text)) {
    throw new ArgumentError(
        "The argument should be a valid identifier. $validIdentifier");
  }

  List<String> chunks = <String>[];
  int chunkStart = 0;
  // The result is that chunk[0] is never capitalized, and chunk[i>0] is always
  // capitalized.
  for (int i = 0; i < text.length; ++i) {
    if (isUpper(text.codeUnitAt(i)) || isNumeric(text.codeUnitAt(i))) {
      chunks.add(text.substring(chunkStart, i));
      chunkStart = i;
    }
  }
  chunks.add(text.substring(chunkStart));

  String result = chunks[0];
  for (int i = 1; i < chunks.length; ++i) {
    if (result.isNotEmpty &&
        !result.endsWith('_')) {
      result += '_';
    }
    result += toLower(chunks[i]);
  }
  return result;
}

/// Removes underscores and [capitalize]s the words which they surround. Throws
/// an [ArgumentError] if the input is not a valid identifier or if camelization
/// produces an invalid identifier (e.g. "_1_" would be camelized as "1", which
/// is not a valid identifier).
String camelize(String text) {
  if (!isValidIdentifier(text)) {
    throw new ArgumentError(
        "The argument should be a valid identifier. $validIdentifier");
  }
  String result =
    text.splitMapJoin('_', onMatch: (_) => '', onNonMatch: capitalize);
  if (!isValidIdentifier(result)) {
    throw new ArgumentError(
        "The argument should be such that the output of camelize is a valid " +
        "identifier. $validIdentifier");
  }
  return result;
}

/// Checks that [text] contains only alphanumeric (a-z, A-Z, 0-9) characters and
/// underscores, and that it doesn't start with a digit.
bool isValidIdentifier(String text) {
  if (text.isEmpty) return false;
  if (!isAlphabetical(text.codeUnitAt(0)) &&
      !isUnderscore(text.codeUnitAt(0))) return false;
  for (int i = 1; i < text.length; ++i) {
    if (!isAlphanumericOrUnderscore(text.codeUnitAt(i))) return false;
  }
  return true;
}

/// Uppers the first letter of the word and lowers the rest. If the word is
/// empty just returns it.
String capitalize(String word) {
  if (word.isEmpty) return word;
  return charToUpper(word[0]) + toLower(word.substring(1));
}

/// Makes a string containing a single latin letter uppercase. Assumes that the
/// size of [string] is 1.
String charToUpper(String string) {
  int codeUnit = string.codeUnitAt(0);
  if (isLower(codeUnit)) {
    codeUnit += 'A'.codeUnitAt(0) - 'a'.codeUnitAt(0);
  }
  return new String.fromCharCode(codeUnit);
}

/// Makes all latin letters in [string] lowercase.
String toLower(String string) {
  List<int> codeUnits = new List<int>(string.length);
  for (int i = 0; i < string.length; ++i) {
    codeUnits[i] = string.codeUnitAt(i);
    if (isUpper(codeUnits[i])) {
      codeUnits[i] += 'a'.codeUnitAt(0) - 'A'.codeUnitAt(0);
    }
  }
  return new String.fromCharCodes(codeUnits);
}

/// Checks if [charCode] corresponds to a latin letter, a digit, or the
/// underscore character.
bool isAlphanumericOrUnderscore(int charCode) {
  return isAlphabetical(charCode) ||
    isNumeric(charCode) ||
    isUnderscore(charCode);
}

/// Checks if [charCode] corresponds to a latin letter.
bool isAlphabetical(int charCode) {
  return isLower(charCode) || isUpper(charCode);
}

/// Checks if [charCode] corresponds to a lowercase latin letter.
bool isLower(int charCode) {
  final int a = 'a'.codeUnitAt(0);
  final int z = 'z'.codeUnitAt(0);
  return a <= charCode && charCode <= z;
}

/// Checks if [charCode] corresponds to an uppercase latin letter.
bool isUpper(int charCode) {
  final int A = 'A'.codeUnitAt(0);
  final int Z = 'Z'.codeUnitAt(0);
  return A <= charCode && charCode <= Z;
}

/// Checks if [charCode] corresponds to a digit.
bool isNumeric(int charCode) {
  final int _0 = '0'.codeUnitAt(0);
  final int _9 = '9'.codeUnitAt(0);
  return _0 <= charCode && charCode <= _9;
}

/// Checks if [charCode] corresponds the underscore character.
bool isUnderscore(int charCode) {
  final int _ = '_'.codeUnitAt(0);
  return _ == charCode;
}
