// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.program_info;

import 'dart:async' show
    Future,
    Stream,
    StreamSink;

import 'dart:io' as io;

import 'dart:convert' show
    JSON,
    LineSplitter,
    UTF8;

import 'dart:typed_data' show
    Int32List;

import 'package:compiler/src/elements/elements.dart' show
    LibraryElement;

import 'package:persistent/persistent.dart' show
    Pair;

import 'vm_commands.dart' show
    MapId,
    ProgramInfoCommand;

import 'dartino_system.dart' show
    DartinoSystem;

import 'src/dartino_selector.dart' show
    DartinoSelector;

enum Configuration {
  Offset64BitsDouble,
  Offset64BitsFloat,
  Offset32BitsDouble,
  Offset32BitsFloat,
}


class IdOffsetMapping {
  final Map<MapId, Map<int, String>> symbolicNames;
  final Map<MapId, Map<String, int>> symbolicNamesReverseMapping;
  final NameOffsetMapping nameOffsets;

  IdOffsetMapping(Map<MapId, Map<int, String>> symbolicNames, this.nameOffsets)
    : symbolicNames = symbolicNames,
      symbolicNamesReverseMapping = invertedMapIdMap(symbolicNames);

  int functionIdFromOffset(Configuration configuration, int offset) {
    return symbolicNamesReverseMapping[MapId.methods]
        [nameOffsets.functionName(configuration, offset)];
  }

  int offsetFromFunctionId(Configuration conf, int functionId) {
    return nameOffsets.functionOffset(
        conf, symbolicNames[MapId.methods][functionId]);
  }

  int classIdFromOffset(Configuration configuration, int offset) {
    return symbolicNamesReverseMapping[MapId.classes]
        [nameOffsets.className(configuration, offset)];
  }
}

/// The information that is stored in a '.info.json' file when a snapshot is
/// created.
class NameOffsetMapping {
  // Maps selector-id -> selector name
  final List<String> selectorNames;

  // Maps configuration -> offset -> name
  final Map<Configuration, Map<int, String>> programObjectNames;
  // Maps configuration -> name -> offset
  final Map<Configuration, Map<String, int>>
      programObjectNamesReverseMapping;

  // Snapshot hash for validation.
  final snapshotHash;

  NameOffsetMapping(this.selectorNames,
              Map<Configuration, Map<int, String>> programObjectNames,
              this.snapshotHash)
    : programObjectNames = programObjectNames,
      programObjectNamesReverseMapping =
          invertedConfigurationMap(programObjectNames);

  String functionName(Configuration conf, int functionOffset) {
    return programObjectNames[conf][functionOffset];
  }

  String className(Configuration conf, int classOffset) {
    return programObjectNames[conf][classOffset];
  }

  String selectorName(DartinoSelector selector) {
    return selectorNames[selector.id];
  }

  int functionOffset(Configuration conf, String symbolicName) {
    return programObjectNamesReverseMapping[conf][symbolicName];
  }
}

Map<Configuration, Map<String, int>> invertedConfigurationMap(
    Map<Configuration, Map<int, String>> map) {
  Map<Configuration, Map<String, int>> result =
  new Map<Configuration, Map<String, int>>();
  for (Configuration configuration in map.keys) {
    result[configuration] = new Map<String, int>();
    map[configuration].forEach((int k, String v) {
      result[configuration][v] = k;
    });
  }
  return result;
}

Map<MapId, Map<String, int>> invertedMapIdMap(
    Map<MapId, Map<int, String>> map) {
  Map<MapId, Map<String, int>> result =
  new Map<MapId, Map<String, int>>();
  for (MapId mapId in map.keys) {
    result[mapId] = new Map<String, int>();
    map[mapId].forEach((int k, String v) {
      result[mapId][v] = k;
    });
  }
  return result;
}

String shortName(String symbolicName) {
  List<String> parts = symbolicName.split("#").sublist(1);
  List<String> partsOfLast = parts.last.split("-");
  parts[parts.length - 1] = partsOfLast.first;

  for (int i = 1; i < partsOfLast.length; i++) {
    if (!partsOfLast[i].startsWith("closure")) break;
    parts.add("<anonymous>");
  }
  return parts.join(".");
}

abstract class ProgramInfoJson {
  static const Map<Configuration, String> configurationNames =
    const <Configuration, String>{
      Configuration.Offset32BitsFloat: 'b32float',
      Configuration.Offset32BitsDouble: 'b32double',
      Configuration.Offset64BitsFloat: 'b64float',
      Configuration.Offset64BitsDouble: 'b64double'};

  static String encode(
      NameOffsetMapping nameOffsetMapping,
      {List<Configuration> enabledConfigs}) {
    if (enabledConfigs == null) {
      enabledConfigs = Configuration.values;
    }

    Map<String, List<int>> buildTables(
        Map<Configuration, Map<int, String>> programObjectNames) {

      List<int> convertMap(Configuration conf) {
        if (enabledConfigs.contains(conf)) {
          Map<int, String> map = programObjectNames[conf];
          List<dynamic> list = new List<dynamic>(map.length * 2);
          int offset = 0;
          map.forEach((int a, String b) {
            list[offset++] = a;
            list[offset++] = b;
          });
          return list;
        } else {
          return const [];
        }
      }

      return new Map<String, List<int>>
          .fromIterable(Configuration.values,
              key: (Configuration conf) => configurationNames[conf],
              value: convertMap);
    }

    return JSON.encode({
      'selectors': nameOffsetMapping.selectorNames,
      'program-object-names': buildTables(nameOffsetMapping.programObjectNames),
      'hashtag': nameOffsetMapping.snapshotHash,
    });
  }

  static NameOffsetMapping decode(String string) {
    var json = JSON.decode(string);

    void ensureFormat(String key) {
      if (json[key] is! Map) {
        throw new FormatException("Expected '$key' to be a map.");
      }
      for (String configurationName in configurationNames.values) {
        if (json[key][configurationName] is! List) {
          throw new FormatException(
              "Expected '$key.$configurationName' to be a List.");
        }
        for (int i = 0; i < json[key][configurationName].length; i += 2) {
          if (json[key][configurationName][i] is! int) {
            throw new FormatException(
                "Found non-integer in '$key.$configurationName[$i]'.");
          }
          String name = json[key][configurationName][i + 1];
          if (name != null && name is! String) {
            throw new FormatException(
                "Found non-string in '$key.$configurationName[${i+1}]'.");
          }
        }
      }
    }

    ensureFormat('program-object-names');

    if (json['hashtag'] is! int) {
      throw new FormatException(
          "Expected 'hashtag' to be an integer.");
    }

    if (json['selectors'] is! List) {
      throw new FormatException(
          "Expected 'selectors' to be a list");
    }
    for (var i in json['selectors']) {
      if (i is! String) {
        throw new FormatException("Found non-string in 'selectors'.");
      }
    }

    Map<int, String> convertList(List<dynamic> list) {
      Map<int, String> map = new Map<int, String>();
      for (int i = 0; i < list.length; i += 2) {
        map[list[i]] = list[i + 1];
      }
      return map;
    }

    Map convertNames(String key) {
      Map<Configuration, Map<int, String>> result =
          new Map<Configuration, Map<int, String>>();
      configurationNames.forEach(
          (Configuration conf, String configurationName) {
        result[conf] = convertList(json[key][configurationName]);
      });
      return result;
    }

    var programObjectNames = convertNames('program-object-names');

    return new NameOffsetMapping(
        json['selectors'],
        programObjectNames,
        json['hashtag']);
  }
}

IdOffsetMapping buildIdOffsetMapping(
    Iterable<LibraryElement> libraries,
    DartinoSystem system,
    ProgramInfoCommand result) {
  Map<MapId, Map<int, String>> symbolicNames =
      system.computeSymbolicSystemInfo(libraries);

  NameOffsetMapping nameOffsetMapping = buildNameOffsetMapping(
      symbolicNames, system, result);
  return new IdOffsetMapping(symbolicNames, nameOffsetMapping);
}

NameOffsetMapping buildNameOffsetMapping(
    Map<MapId, Map<int, String>> symbolicNames,
    DartinoSystem system,
    ProgramInfoCommand result) {

  Map<Configuration, Map<int, String>> programObjectNames =
      new Map<Configuration, Map<int, String>>.fromIterable(
          Configuration.values,
          value: (Configuration conf) => new Map<int, String>());

  List<String> selectors = new List(system.symbolByDartinoSelectorId.length);

  system.symbolByDartinoSelectorId.forEach((Pair<int, String> pair) {
    selectors[pair.fst] = pair.snd;
  });

  void fillTable(Int32List list, String symbolicNameFromId(int id)) {
    for (int offset = 0;
         offset < list.length;
         offset += Configuration.values.length + 1) {
      int id = list[offset + 0];
      String symbolicName = symbolicNameFromId(id);
      for (Configuration conf in Configuration.values) {
        programObjectNames[conf][list[offset + conf.index + 1]] = symbolicName;
      }
    }
  }

  fillTable(result.functionOffsetTable, (int id) {
    return symbolicNames[MapId.methods][id];
  });

  fillTable(result.classOffsetTable, (id) {
    return symbolicNames[MapId.classes][id];
  });

  return new NameOffsetMapping(
      selectors, programObjectNames, result.snapshotHash);
}

// We are only interested in two kind of lines in the dartino.ticks file.
final RegExp tickRegexp =
    new RegExp(r'^0x([0-9a-f]+),0x([0-9a-f]+),0x([0-9a-f]+)');
final RegExp propertyRegexp = new RegExp(r'^(\w+)=(.*$)');

// Tick contains information from a line matching tickRegexp.
class Tick {
  // The actual program counter where the tick occurred.
  final int pc;
  // The bytecode pointer as an offset relative to program heap start.
  final int bcp;
  final int hashtag;
  Tick(this.pc, this.bcp,this.hashtag);
}

// Property contains information from a line matching propertyRegexp.
class Property {
  final String name;
  final String value;
  Property(this.name, this.value);
}

// FunctionInfo captures profiler information for a function.
class FunctionInfo {
  int ticks = 0;  // Accumulated number of ticks.
  final String name;  // Name that identifies the function.

  FunctionInfo(this.name);

  int percent(int total_ticks) => ticks * 100 ~/ total_ticks;

  String stringRepresentation(int total_ticks, NameOffsetMapping info) {
    return " -${percent(total_ticks).toString().padLeft(3, ' ')}% "
        "${shortName(name)}";
  }

  static String ComputeName(String function_name, String class_name) {
    if (class_name == null) return function_name;
    return "$class_name.$function_name";
  }
}

Stream decodeTickStream(Stream<List<int>> input) async* {
  Stream<String> inputLines =
      input.transform(UTF8.decoder).transform(new LineSplitter());
  await for (String line in inputLines) {
    Match t = tickRegexp.firstMatch(line);
    if (t != null) {
      int pc = int.parse(t.group(1), radix: 16);
      int offset = 0;
      int hashtag = 0;
      if (t.groupCount > 1) {
        offset = int.parse(t.group(2), radix: 16);
        hashtag = int.parse(t.group(3), radix: 16);
      }
      yield new Tick(pc, offset, hashtag);
    } else {
      t = propertyRegexp.firstMatch(line);
      if (t != null) yield new Property(t.group(1), t.group(2));
    }
  }
}

// Binary search for named entry start.
NamedEntry findEntry(List<NamedEntry> functions, Tick t) {
  int low = 0;
  int high = functions.length - 1;
  while (low + 1 < high) {
    int i = low + ((high - low) ~/ 2);
    NamedEntry current = functions[i];
    if (current.offset < t.bcp) {
      low = i;
    } else {
      high = i;
    }
  }
  return functions[low];
}

// NamedEntry captures a named entry caputred in the .info.json file.
class NamedEntry {
  final int offset;
  final String name;
  NamedEntry(this.offset, this.name);
}

class Profile {
  Profile();

  // Tick information.
  int total_ticks = 0;
  int runtime_ticks = 0;
  int interpreter_ticks = 0;
  int discarded_ticks = 0;
  int other_snapshot_ticks = 0;

  // Memory model.
  String model;

  // All the ticks.
  List<Tick> ticks = <Tick>[];

  // The resulting histogram.
  List<FunctionInfo> histogram;

  String formatted(NameOffsetMapping info) {
    StringBuffer buffer;
    buffer.writeln("# Tick based profiler result.");

    for (FunctionInfo func in histogram) {
      if (func.percent(total_ticks) < 2) break;
      buffer.writeln(func.stringRepresentation(total_ticks, info));
    }

    buffer.writeln("# ticks in interpreter=${interpreter_ticks}");
    if (runtime_ticks > 0) print("  runtime=${runtime_ticks}");
    if (discarded_ticks > 0) print("  discarded=${discarded_ticks}");
    if (other_snapshot_ticks> 0) {
      buffer.writeln("  other_snapshot=${other_snapshot_ticks}");
    }
    return buffer.toString();
  }
}

Future<Profile> decodeTickSamples(
    NameOffsetMapping info,
    Stream<List<int>> sampleStream,
    Stream<List<int>> input,
    StreamSink<List<int>> output) async {
  Profile profile = new Profile();

  // Process the tick sample file.
  await for (var t in decodeTickStream(sampleStream)) {
    if (t is Tick) {
      profile.ticks.add(t);
    } else if (t is Property) {
      if (t.name == 'discarded') profile.discarded_ticks = int.parse(t.value);
      if (t.name == 'model') profile.model = t.value;
    }
  }
  if (profile.model == null) {
    print("Memory model absent in sample file.");
    return null;
  }

  // Compute the configuration key based on the memory model.
  Configuration conf;
  String model = profile.model;
  if (model == 'b64double') {
    conf = Configuration.Offset64BitsDouble;
  } else if (model == 'b64float') {
    conf = Configuration.Offset64BitsFloat;
  } else if (model == 'b32double') {
    conf = Configuration.Offset32BitsDouble;
  } else if (model == 'b32float') {
    conf = Configuration.Offset32BitsFloat;
  } else {
    print("Memory model in sample file ${model} cannot be recognized.");
    return null;
  }

  // Compute a offset sorted list of Function entries.
  List<NamedEntry> functions = new List<NamedEntry>();
  Map<int,String> programObjectNames = info.programObjectNames[conf];
  programObjectNames.forEach((int offset, String name) {
    if (name.endsWith("-method")) {
      functions.add(new NamedEntry(offset, name));
    }
  });
  functions.sort((a, b) => a.offset - b.offset);

  Map<String, FunctionInfo> results = <String, FunctionInfo>{};
  for (Tick t in profile.ticks) {
    profile.total_ticks++;
    if (t.bcp == 0) {
      profile.runtime_ticks++;
    } else if (t.hashtag != info.snapshotHash) {
      profile.other_snapshot_ticks++;
    } else {
      profile.interpreter_ticks++;
      String name = findEntry(functions, t).name;
      if (name != null) {
        FunctionInfo f =
            results.putIfAbsent(name, () => new FunctionInfo(name));
        f.ticks++;
      }
    }
  }

  // Sort the values into the histogram.
  List<FunctionInfo> histogram =
    new List<FunctionInfo>.from(results.values);
  histogram.sort((a,b) { return b.ticks - a.ticks; });
  profile.histogram = histogram;

  return profile;
}

Configuration getConfiguration(int wordSize, int dartinoDoubleSize) {
  if (wordSize == 64) {
    if (dartinoDoubleSize == 32) return Configuration.Offset64BitsFloat;
    else if (dartinoDoubleSize == 64) return Configuration.Offset64BitsDouble;
  } else if (wordSize == 32) {
    if (dartinoDoubleSize == 32) return Configuration.Offset32BitsFloat;
    else if (dartinoDoubleSize == 64) return Configuration.Offset32BitsDouble;
  }
  throw 'Invalid arguments $wordSize $dartinoDoubleSize';
}
