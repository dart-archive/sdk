// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.program_info;

import 'dart:async' show
    Future,
    Stream;

import 'dart:io' as io;

import 'dart:io' show
    BytesBuilder;

import 'dart:convert' show
    JSON,
    LineSplitter,
    UTF8;

import 'dart:typed_data' show
    Int32List,
    Uint8List,
    ByteData,
    Endianness;

import 'package:persistent/persistent.dart' show
    Pair;

import 'commands.dart' show
    WriteSnapshotResult;

import 'fletch_system.dart' show
    FletchClass,
    FletchFunction,
    FletchSystem;

import 'src/fletch_selector.dart' show
    FletchSelector;

enum Configuration {
  Offset64BitsDouble,
  Offset64BitsFloat,
  Offset32BitsDouble,
  Offset32BitsFloat,
}

class ProgramInfo {
  final List<String> _strings;

  // Maps selector-id -> string-id
  final List<int> _selectorNames;

  // Maps configuration -> offset -> string-id
  final Map<Configuration, Map<int, int>> _classNames;

  // Maps configuration -> offset -> string-id
  final Map<Configuration, Map<int, int>> _functionNames;

  ProgramInfo(this._strings, this._selectorNames,
              this._classNames, this._functionNames);

  String classNameOfFunction(Configuration conf, int functionOffset) {
    return _getString(_classNames[conf][functionOffset]);
  }

  String functionName(Configuration conf, int functionOffset) {
    return _getString(_functionNames[conf][functionOffset]);
  }

  String className(Configuration conf, int classOffset) {
    return _getString(_classNames[conf][classOffset]);
  }

  String selectorName(FletchSelector selector) {
    return _getString(_selectorNames[selector.id]);
  }

  String _getString(int stringId) {
    String name = null;
    if (stringId != null && stringId != -1) {
      name = _strings[stringId];
      if (name == '') name = null;
    }
    return name;
  }
}

abstract class ProgramInfoJson {
  static String encode(ProgramInfo info, {List<Configuration> enabledConfigs}) {
    if (enabledConfigs == null) {
      enabledConfigs = Configuration.values;
    }

    Map<String, List<int>> buildTables(
        Map<Configuration, Map<int, int>> offset2stringIds) {

      List<int> convertMap(Configuration conf) {
        if (enabledConfigs.contains(conf)) {
          var map = offset2stringIds[conf];
          List<int> list = new List<int>(map.length * 2);
          int offset = 0;
          map.forEach((int a, int b) {
            list[offset++] = a;
            list[offset++] = b;
          });
          return list;
        } else {
          return const [];
        }
      }

      return {
        'b64double': convertMap(Configuration.Offset64BitsDouble),
        'b64float':  convertMap(Configuration.Offset64BitsFloat),
        'b32double': convertMap(Configuration.Offset32BitsDouble),
        'b32float':  convertMap(Configuration.Offset32BitsFloat),
      };
    }

    return JSON.encode({
      'strings': info._strings,
      'selectors': info._selectorNames,
      'class-names': buildTables(info._classNames),
      'function-names' : buildTables(info._functionNames),
    });
  }

  static ProgramInfo decode(String string) {
    var json = JSON.decode(string);

    Map<int, int> convertList(List<int> list) {
      Map<int, int> map = {};
      for (int i = 0; i < list.length; i += 2) {
        map[list[i]] = list[i + 1];
      }
      return map;
    }

    var classNames = {
      Configuration.Offset64BitsDouble :
          convertList(json['class-names']['b64double']),
      Configuration.Offset64BitsFloat:
          convertList(json['class-names']['b64float']),
      Configuration.Offset32BitsDouble :
          convertList(json['class-names']['b32double']),
      Configuration.Offset32BitsFloat :
          convertList(json['class-names']['b32float']),
    };

    var functionNames = {
      Configuration.Offset64BitsDouble :
          convertList(json['function-names']['b64double']),
      Configuration.Offset64BitsFloat:
          convertList(json['function-names']['b64float']),
      Configuration.Offset32BitsDouble :
          convertList(json['function-names']['b32double']),
      Configuration.Offset32BitsFloat :
          convertList(json['function-names']['b32float']),
    };

    return new ProgramInfo(
        json['strings'], json['selectors'], classNames, functionNames);
  }
}

abstract class ProgramInfoBinary {
  static const int _INVALID_INDEX = 0xffffff;
  static final int _HEADER_LENGTH = 4 * (2 + 2 * Configuration.values.length);

  static List<int> encode(ProgramInfo info,
                          {List<Configuration> enabledConfigs}) {
    if (enabledConfigs == null) {
      enabledConfigs = Configuration.values;
    }

    List<int> stringOffsetsInStringTable = [];

    List<int> buildStringTable() {
      BytesBuilder builder = new BytesBuilder();
      for (int i = 0; i < info._strings.length; i++) {
        stringOffsetsInStringTable.add(builder.length);
        String name = info._strings[i];
        if (name != null) {
          builder.add(UTF8.encode(name));
        }
        builder.addByte(0);
      }
      return builder.takeBytes();
    }

    List<int> buildSelectorTable(List<int> stringIds) {
      Uint8List bytes = new Uint8List(3 * stringIds.length);

      int offset = 0;

      void writeByte(int byte) {
        bytes[offset++] = byte;
      }

      void writeNumber(int number) {
        // 0xffffff means -1
        assert(number < ((1 << 24) - 1));

        if (number == -1) number = _INVALID_INDEX;

        writeByte(number & 0xff);
        writeByte((number >> 8) & 0xff);
        writeByte((number >> 16) & 0xff);
      }

      // We write tuples [program-offset, string-table-offset].
      // So the user can use binary search using a program offset to find the
      // string offset.
      for (int i = 0; i < stringIds.length; i++) {
        int stringId = stringIds[i];

        if (stringId != -1) {
          int stringOffset = stringOffsetsInStringTable[stringId];
          writeNumber(stringOffset);
        } else {
          writeNumber(-1);
        }
      }

      assert(offset == bytes.length);

      return bytes;
    }

    List<int> buildOffsetTable(Map<int, int> map) {
      Uint8List bytes = new Uint8List(2 * 3 * map.length);

      int offset = 0;

      void writeByte(int byte) {
        bytes[offset++] = byte;
      }

      void writeNumber(int number) {
        // 0xffffff means -1
        assert(number < ((1 << 24) - 1));

        if (number == -1) number = _INVALID_INDEX;

        writeByte(number & 0xff);
        writeByte((number >> 8) & 0xff);
        writeByte((number >> 16) & 0xff);
      }

      // We write tuples [program-offset, string-table-offset].
      // So the user can use binary search using a program offset to find the
      // string offset.
      List<int> offsets = map.keys.toList()..sort();
      for (int i = 0; i < offsets.length; i++) {
        int offset = offsets[i];
        int stringId = map[offset];

        // We only make an entry for [offset] if there is a known string.
        if (stringId != -1) {
          int stringOffset = stringOffsetsInStringTable[stringId];
          writeNumber(offset);
          writeNumber(stringOffset);
        }
      }

      return new Uint8List.view(bytes.buffer, 0, offset);
    }

    List<List<int>> tables = [];
    tables.add(buildStringTable());
    tables.add(buildSelectorTable(info._selectorNames));
    for (Configuration conf in Configuration.values) {
      if (enabledConfigs.contains(conf)) {
        List<int> offsetTable = buildOffsetTable(info._classNames[conf]);
        tables.add(offsetTable);
      } else {
        tables.add([]);
      }
    }
    for (Configuration conf in Configuration.values) {
      if (enabledConfigs.contains(conf)) {
        List<int> offsetTable = buildOffsetTable(info._functionNames[conf]);
        tables.add(offsetTable);
      } else {
        tables.add([]);
      }
    }

    int tableLengths = tables.map((t) => t.length).fold(0, (a, b) => a + b);
    int length = _HEADER_LENGTH + tableLengths;

    Uint8List bytes = new Uint8List(length);
    ByteData header = new ByteData.view(bytes.buffer);

    int offset = 0;
    writeLength(List<int> data) {
      header.setUint32(offset, data.length, Endianness.LITTLE_ENDIAN);
      offset += 4;
    }
    writeTable(List<int> data) {
      bytes.setRange(offset, offset + data.length, data);
      offset += data.length;
    }

    tables.forEach(writeLength);
    assert(offset == _HEADER_LENGTH);
    tables.forEach(writeTable);

    return bytes;
  }

  static ProgramInfo decode(List<int> data) {
    Uint8List bytes = new Uint8List.fromList(data);
    ByteData header = new ByteData.view(bytes.buffer);

    int offset = 0;
    int readLength() {
      int length = header.getUint32(offset, Endianness.LITTLE_ENDIAN);
      offset += 4;
      return length;
    }
    List<int> readTable(int length) {
      var view = new Uint8List.view(bytes.buffer, offset, length);
      offset += length;
      return view;
    }

    Map<int, int> stringOffsetToIndex = {};
    List<String> buildStringDecodingTable(List<int> data) {
      List<String> strings = [];
      int start = 0;
      while (start < data.length) {
        stringOffsetToIndex[start] = strings.length;

        int end = start;
        while (data[end] != 0) end++;

        strings.add(UTF8.decode(data.sublist(start, end)));
        start = end + 1;
      }
      return strings;
    }

    List<int> decodeSelectors(List<int> data) {
      assert(data.length % 3 == 0);
      List<int> indices = new List(data.length ~/ 3);
      for (int offset = 0; offset < data.length; offset += 3) {
        int number =
            data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16);
        if (number == _INVALID_INDEX) number = -1;
        if (number != -1) number = stringOffsetToIndex[number];
        indices[offset ~/ 3] = number;
      }
      return indices;
    }

    Map<int, int> decodeTable(List<int> data) {
      assert(data.length % 6 == 0);
      Map<int, int> offset2stringId = {};
      for (int offset = 0; offset < data.length; offset += 6) {
        int programOffset =
            data[offset] |
            (data[offset + 1] << 8) |
            (data[offset + 2] << 16);
        int stringOffset =
            data[offset + 3] |
            (data[offset + 4] << 8) |
            (data[offset + 5] << 16);

        if (programOffset != _INVALID_INDEX && stringOffset != _INVALID_INDEX) {
          offset2stringId[programOffset] = stringOffsetToIndex[stringOffset];
        } else {
          offset2stringId[programOffset] = -1;
        }
      }
      return offset2stringId;
    }

    int stringTableLength = readLength();
    int selectorTableLength = readLength();

    Map<Configuration, int> classTableLengths = {};
    Configuration.values.forEach(
        (conf) => classTableLengths[conf] = readLength());

    Map<Configuration, int> functionTableLengths = {};
    Configuration.values.forEach(
        (conf) => functionTableLengths[conf] = readLength());

    List<int> stringTable = readTable(stringTableLength);

    List<String> strings = buildStringDecodingTable(stringTable);
    List<int> selectorTable = decodeSelectors(readTable(selectorTableLength));

    Map<Configuration, Map<int, int>> classNames = {};
    Configuration.values.forEach((conf) {
      classNames[conf] = decodeTable(readTable(classTableLengths[conf]));
    });

    Map<Configuration, Map<int, int>> functionNames = {};
    Configuration.values.forEach((conf) {
      functionNames[conf] = decodeTable(readTable(functionTableLengths[conf]));
    });

    assert(offset == (_HEADER_LENGTH +
                      stringTableLength +
                      selectorTableLength +
                      classTableLengths.values.fold(0, (a, b) => a + b) +
                      functionTableLengths.values.fold(0, (a, b) => a + b)));

    return new ProgramInfo(
        strings,
        selectorTable,
        classNames,
        functionNames);
  }
}

ProgramInfo buildProgramInfo(FletchSystem system, WriteSnapshotResult result) {
  List<String> strings = [];
  Map<String, int> stringIndices = {};
  List<int> selectors = [];

  int newName(String name) {
    if (name == null) return -1;

    var index = stringIndices[name];
    if (index == null) {
      index = strings.length;
      strings.add(name);
      stringIndices[name] = index;
    }
    return index;
  }

  void setIndex(List<int> list, int index, value) {
    while (list.length <= index) {
      list.add(-1);
    }
    list[index] = value;
  }

  system.symbolByFletchSelectorId.forEach((Pair<int, String> pair) {
    setIndex(selectors, pair.fst, newName(pair.snd));
  });

  Map<int, FletchClass> functionId2Class = {};
  system.classesById.forEach((Pair<int, FletchClass> pair) {
    FletchClass klass = pair.snd;
    klass.methodTable.forEach((Pair<int, int> pair) {
      int functionId = pair.snd;
      functionId2Class[functionId] = klass;
    });
  });

  Map<Configuration, Map<int, int>> newTable() {
    return <Configuration, Map<int, int>>{
      Configuration.Offset64BitsDouble : <int,int>{},
      Configuration.Offset64BitsFloat : <int,int>{},
      Configuration.Offset32BitsDouble : <int,int>{},
      Configuration.Offset32BitsFloat : <int,int>{},
    };
  }

  fillTable(Map<Configuration, Map<int, int>> dst,
            Int32List list,
            String symbol(int id)) {
    for (int offset = 0; offset < list.length; offset += 5) {
      int id = list[offset + 0];
      int stringId = newName(symbol(id));

      if (stringId != -1) {
        dst[Configuration.Offset64BitsDouble][list[offset + 1]] = stringId;
        dst[Configuration.Offset64BitsFloat][list[offset + 2]] = stringId;
        dst[Configuration.Offset32BitsDouble][list[offset + 3]] = stringId;
        dst[Configuration.Offset32BitsFloat][list[offset + 4]] = stringId;
      }
    }
  }

  var functionNames = newTable();
  var classNames = newTable();

  fillTable(functionNames,
            result.functionOffsetTable,
            (id) => system.functionsById[id].name);
  fillTable(classNames,
            result.classOffsetTable,
            (id) {
    FletchClass klass = system.classesById[id];
    if (klass == null) {
      // Why do we get here?
      return null;
    }
    return klass.name;
  });
  fillTable(classNames,
            result.functionOffsetTable,
            (id) {
    FletchClass klass = functionId2Class[id];
    if (klass != null) return klass.name;
    return null;
  });

  return new ProgramInfo(strings, selectors, classNames, functionNames);
}

final RegExp _FrameRegexp =
    new RegExp(r'^Frame +([0-9]+): Function\(([0-9]+)\)$');

final RegExp _NSMRegexp =
    new RegExp(r'^NoSuchMethodError\(([0-9]+), ([0-9]+)\)$');

Stream<String> decodeStackFrames(Configuration conf,
                                 ProgramInfo info,
                                 Stream<String> input) async* {
  await for (String line in input) {
    Match frameMatch = _FrameRegexp.firstMatch(line);
    Match nsmMatch = _NSMRegexp.firstMatch(line);
    if (frameMatch != null) {
      String frameNr = frameMatch.group(1);
      int functionOffset = int.parse(frameMatch.group(2));

      String className = info.classNameOfFunction(conf, functionOffset);
      String functionName = info.functionName(conf, functionOffset);

      if (className == null) {
        yield '   $frameNr: $functionName\n';
      } else {
        yield '   $frameNr: $className.$functionName\n';
      }
    } else if (nsmMatch != null) {
      int classOffset = int.parse(nsmMatch.group(1));
      FletchSelector selector =
          new FletchSelector(int.parse(nsmMatch.group(2)));
      String functionName = info.selectorName(selector);
      String className = info.className(conf, classOffset);

      if (className != null && functionName != null) {
        yield 'NoSuchMethodError: $className.$functionName\n';
      } else if (functionName != null) {
        yield 'NoSuchMethodError: $functionName\n';
      } else {
        yield 'NoSuchMethodError: <unknown method>\n';
      }
    } else {
      yield '$line\n';
    }
  }
}

Future<int> decodeProgramMain(List<String> arguments) async {
  usage(message) {
    print("Invalid arguments: $message");
    print("Usage: ${io.Platform.script} "
          "<32/64> <float/double> <snapshot.info.{json/bin}>");
  }

  if (arguments.length != 3) {
    usage("Exactly 3 arguments must be supplied");
    return 1;
  }

  String bits = arguments[0];
  if (!['32', '64'].contains(bits)) {
    usage("Bit width must be 32 or 64.");
    return 1;
  }

  String floatOrDouble = arguments[1];
  if (!['float', 'double'].contains(floatOrDouble)) {
    usage("Floating point argument must be 'float' or 'double'.");
    return 1;
  }

  String filename = arguments[2];
  bool isJsonFile = filename.endsWith('.json');
  bool isBinFile = filename.endsWith('.bin');
  if (!isJsonFile && !isBinFile) {
    usage("The program info file must end in '.bin' or '.json' "
          "(was: '$filename').");
    return 1;
  }

  io.File file = new io.File(filename);
  if (!await file.exists()) {
    usage("The file '$filename' does not exist.");
    return 1;
  }

  ProgramInfo info;

  if (isJsonFile) {
    info = ProgramInfoJson.decode(await file.readAsString());
  } else {
    info = ProgramInfoBinary.decode(await file.readAsBytes());
  }

  Stream<String> inputLines =
      io.stdin.transform(UTF8.decoder).transform(new LineSplitter());

  Configuration conf = _getConfiguration(bits, floatOrDouble);
  Stream<String> decodedFrames = decodeStackFrames(conf, info, inputLines);
  await decodedFrames.transform(UTF8.encoder).pipe(io.stdout);

  return 0;
}

Configuration _getConfiguration(bits, floatOrDouble) {
  if (bits == '64') {
    if (floatOrDouble == 'float') return Configuration.Offset64BitsFloat;
    else if (floatOrDouble == 'double') return Configuration.Offset64BitsDouble;
  } else if (bits == '32') {
    if (floatOrDouble == 'float') return Configuration.Offset32BitsFloat;
    else if (floatOrDouble == 'double') return Configuration.Offset32BitsDouble;
  }
  throw 'Invalid arguments';
}
