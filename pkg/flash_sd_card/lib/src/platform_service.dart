// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:power_management/power_management.dart' as power_management;

import 'context.dart';

/// The PlaformService class provide the methods which can vary from
/// platform to platform. These are mainly methods for handling SD cards.
///
/// Most of the methods are implemented by running platform specific
/// commands and to some extend interpreting their output on stdout/stderr.
abstract class PlatformService {
  final Context ctx;

  factory PlatformService(Context ctx) {
    if (Platform.isMacOS) {
      return new MacOSPlatformService(ctx);
    } else if (Platform.isLinux) {
      return new LinuxPlatformService(ctx);
    } else {
      ctx.failure('Unsupported OS ${Platform.operatingSystem}');
    }
  }

  PlatformService._(this.ctx);

  /// Perform async initialization on the platform service object.
  Future initialize() async {
    await power_management.initPowerManagement();
  }

  /// Find an SD card through user interaction. The user is asked to remove
  /// and insert the SD card and through diffing the content of '/dev' the
  /// device name for the card is determined.
  Future<String> findSDCard() async {
    await ctx.readLine(
        'Please remove all SD cards from this computer. Then press Enter.');
    Set defaultDisks = new Set.from(await listPossibleSDCards());
    ctx.log('Default disks $defaultDisks');

    // Wait for an additional disk.
    await ctx.readLine(
      'Please insert the SD card you want to use with Fletch. '
      'Then press Enter.');
    int retryCount = 10;
    while (true) {
      Set disks = new Set.from(await listPossibleSDCards());
      ctx.log('Disks $disks');
      Set diff = disks.difference(defaultDisks);
      if (diff.length == 1) {
        return diff.first;
      }

      if (--retryCount == 0) return null;

      // Wait for one second.
      await sleep(1000);
    }
  }

  /// Provide a list of possible SD card devices.
  Future<List<String>> listPossibleSDCards();

  /// Download the [url] to [file] and provide progress information.
  Future downloadWithProgress(
      Uri url,
      File destination,
      {int retryCount: 3,
       Duration retryInterval: const Duration(seconds: 3)}) async {

    Future doDownload(HttpClient client) async {
      ctx.log('Downloading $url');
      var request = await client.getUrl(url);
      var response = await request.close();
      ctx.log('Response headers:\n${response.headers}');

      int totalBytes = response.headers.contentLength;
      int bytes = 0;
      StreamTransformer progressTransformer =
          new StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> value, EventSink<List<int>> sink) {
              bytes += value.length;
              ctx.updateProgress(
                  'received ${bytes ~/ (1024 * 1024)} Mb '
                  'of ${totalBytes ~/ (1024 * 1024)} Mb');
              sink.add(value);
            },
            handleDone: (EventSink<List<int>> sink) {
              sink.close();
            });
      await response
          .transform(progressTransformer).pipe(destination.openWrite());
    }

    var client;
    int id = power_management.disableSleep('Downloading SD card image');
    try {
      client = new HttpClient();
      int count = 0;
      while (true) {
        count++;
        ctx.startProgress('Downloading: ');
        try {
          await doDownload(client);
          ctx.endProgress('DONE');
          break;
        } catch (e, s) {
          if (count < retryCount) {
            ctx.endProgress(
                'Failed. Retrying in ${retryInterval.inSeconds} seconds.');
            ctx.log('Download failure: $e\n$s');
            await sleep(retryInterval.inMilliseconds);
          } else {
            await ctx.failure('Download failed after $retryCount retries');
          }
        }
      }
    } finally {
      power_management.enableSleep(id);
      await client.close();
    }

    ctx.log('Finished downloading $url');
  }

  /// This function will write the image in the file [image] into the device
  /// specified in [device].
  ///
  /// If the device is an SD card then it must be unmounted before calling this.
  Future ddWithProgress(File source, String device) async {
    StreamTransformer progressTransformer =
        new StreamTransformer<String, String>.fromHandlers(
          handleData: (String value, EventSink<String> sink) {
            String progress = ddProgress(value);
            if (progress != null) {
              ctx.updateProgress(progress);
            } else {
              sink.add(value);
            }
          },
          handleDone: (EventSink<String> sink) {
            ctx.endProgress('DONE');
            sink.close();
          });

    int id = power_management.disableSleep('Writing SD card image');
    ctx.startProgress('Writing: ');
    var process = await Process.start('dd', ddFlags(source, device));
    var stdoutFuture = process.stdout
        .transform(UTF8.decoder)
        .join();
    var stderrFuture = process.stderr
        .transform(UTF8.decoder)
        .transform(progressTransformer)
        .join();

    // Send signal INFO peridocially.
    var timer = new Timer.periodic(
      new Duration(seconds: 1),
      (_) => ctx.runProcess('kill', ['-$ddProgressSignal', '${process.pid}']));

    var exitCode = await process.exitCode;
    timer.cancel();
    if (exitCode != 0) {
      String ddStdout = await stdoutFuture;
      String ddStderr = await stderrFuture;
      ctx.log('Running dd failed $exitCode');
      ctx.log('stdout: $ddStdout');
      ctx.log('stderr: $ddStderr');

      ctx.infoln('Failed to write SD card.');
      ctx.infoln(ddStderr);
      if (ddStderr.contains('Permission denied')) {
        ctx.infoln("Remember to run this command with 'sudo'.");
      }
      await ctx.failure('');
    }
    power_management.enableSleep(id);

    // Sync filesystems before returning.
    ctx.infoln('Running sync.');
    await sync();

    return true;
  }

  /// Sync the filsystems.
  Future sync() async {
    int count = 0;
    while (true) {
      var result = await ctx.runProcess('sync', []);
      if (result.exitCode == 0) break;
      if (count++ == 10) {
        await ctx.failure('Failed to sync filesystems', result.stderr);
      }
      await sleep(1000);
    }
  }

  /// Decompress the content of [zipFile] into the directory [destination].
  Future decompressFile(File zipFile, Directory destination);

  /// Provide platform specific flags to 'dd'.
  List<String> ddFlags(File source, String device);

  /// Platform specific checking of if stderr output [value] is 'dd' progress
  /// information. If that is the case the returned value is the progress
  /// information to display.
  String ddProgress(String value);

  /// The signal name to send to 'dd' to get progress information on stderr.
  String get ddProgressSignal;

  /// Provide user-readable information on a disk device.
  Future<String> diskInfo(String device);

  /// Unmount disk device.
  Future unmountDisk(String device);

  /// Mount disk device. This actually mounts partition 1 on the disk.
  ///
  /// Returns a temp directory created for mounting.
  Future<Directory> mountDisk(String device);

  /// Returns a future which completes after [milliseconds] milliseconds.
  Future sleep(int milliseconds) {
    return new Future.delayed(new Duration(milliseconds: milliseconds));
  }
}

/// Implementation of [PlatformService] for Mac OS.
class MacOSPlatformService extends PlatformService {
  MacOSPlatformService(Context ctx) : super._(ctx);

  Future<List<String>> listPossibleSDCards() async {
    ctx.log('Listing content of /dev');
    var result = await Process.run('/bin/ls', ['/dev']);
    if (result.exitCode != 0) {
      ctx.log('Failure listing content of /dev, rc = ${result.exitCode}');
      ctx.log('STDOUT: ${result.stdout}');
      ctx.log('STDERR: ${result.stderr}');
      await ctx.failure('Failed to list content of /dev', result.stderr);
    }
    var rdisks = result.stdout
        .split('\n')
        .where((s) => s.startsWith('rdisk'))
        .where((s) => s.length == 'rdiskX'.length)
        .toList();
    rdisks.sort();
    ctx.log('Found the following possible SD cards $rdisks');
    return rdisks;
  }

  Future decompressFile(File zipFile, Directory destination) async {
    var result = await ctx.runProcess(
        'ditto', ['-x', '-k', zipFile.path, destination.path]);
    if (result.exitCode != 0) {
      await ctx.failure('Failed to decompress SD card image', result.stderr);
    }
  }

  List<String> ddFlags(File source, String device) {
    return ['bs=1m', 'if=${source.path}', 'of=$device'];
  }

  String ddProgress(String value) {
    List<String> lines = value.split('\n');
    if (lines.length >= 3 && lines[2].indexOf('bytes transferred') > 0) {
      return lines[2];
    } else {
      return null;
    }
  }

  String get ddProgressSignal => 'INFO';

  Future<String> diskInfo(String device) async {
    var result = await ctx.runProcess('diskutil', ['list', device]);
    if (result.exitCode != 0) {
      await ctx.failure(
          'Failed to get information on $device (failed on running fdisk)',
          result.stderr);
    }
    return result.stdout;
  }

  Future unmountDisk(String device) async {
    var result = await ctx.runProcess('diskutil', ['unmountDisk', device]);
    if (result.exitCode != 0) {
      await ctx.failure('Failed to unmount $device', result.stderr);
    }
  }

  Future<Directory> mountDisk(String device) async {
    // On Mac OS running
    //   diskutil mountDisk /dev/diskX
    // which should mount all mountable volumes does not seem to work, so mount
    // the boot partition /dev/diskXs1 explicitly.
    //
    // Retry this operation. When mounting right after running dd and sync
    // mounting can fail.
    int retryCount = 10;
    while (true) {
      var result = await ctx.runProcess('diskutil', ['mount', '${device}s1']);
      if (result.exitCode != 0) {
        if (--retryCount == 0) {
          await ctx.failure('Failed to mount $device', result.stderr);
        } else {
          await super.sleep(1000);
        }
      }
      return new Directory('/Volumes/boot');
    }
  }
}

/// Implementation of [PlatformService] for Linux.
class LinuxPlatformService extends PlatformService {
  LinuxPlatformService(Context ctx) : super._(ctx);

  Future<List<String>> listPossibleSDCards() async {
    ctx.log('Listing content of /dev');
    var result = await Process.run('/bin/ls', ['/dev']);
    if (result.exitCode != 0) {
      ctx.log('Failure listing content of /dev, rc = ${result.exitCode}');
      ctx.log('STDOUT: ${result.stdout}');
      ctx.log('STDERR: ${result.stderr}');
      throw 1;
    }

    bool possibleSDCard(String deviceName) {
      return (deviceName.startsWith('sd') &&
              deviceName.length == 'sdX'.length) ||
             (deviceName.startsWith('mmcblk') &&
              deviceName.length == 'mmcblkX'.length);
    }

    var devices = result.stdout
        .split('\n')
        .where(possibleSDCard)
        .toList();
    devices.sort();
    ctx.log('Found the following possible SD cards $devices');
    return devices;
  }

  Future decompressFile(File zipFile, Directory destination) async {
    var result =
        await ctx.runProcess(
            'unzip', ['-o', zipFile.path, '-d', destination.path]);
    if (result.exitCode != 0) {
      await ctx.failure('Failed to decompress SD card image', result.stderr);
    }
  }

  List<String> ddFlags(File source, String device) {
    return ['bs=4M', 'if=${source.path}', 'of=$device', 'oflag=direct'];
  }

  String ddProgress(String value) {
    List<String> lines = value.split('\n');
    if (lines.length >= 3 && lines[2].indexOf('bytes (') > 0) {
      return lines[2];
    } else {
      return null;
    }
  }

  String get ddProgressSignal => 'USR1';

  Future<String> diskInfo(String device) async {
    var result = await ctx.runProcess('fdisk', ['-l', device]);
    if (result.exitCode != 0) {
      await ctx.failure(
          'Failed to get information on $device (failed on running fdisk)',
          result.stderr);
    }
    return result.stdout;
  }

  Future unmountDisk(String device) async {
    // List all mounted devices.
    var result = await ctx.runProcess('df', ['-l', '--output=source']);
    if (result.exitCode != 0) {
      await ctx.failure('Failed to unmount $device (failed on running df)',
                        result.stderr);
    }
    List<String> mountedDevices = result.stdout.split('\n');
    for (var d in mountedDevices) {
      // E.g. if device is /dev/sdc, then /dev/sdc1 and /dev/sdc2 might be
      // mounted.
      if (d.startsWith(device)) {
        result = await ctx.runProcess('umount', [d]);
        if (result.exitCode != 0) {
          await ctx.failure('Failed to unmount $device (failed on $d)',
                            result.stderr);
        }
      }
    }
  }

  Future<Directory> mountDisk(String device) async {
    // Create a temp dir for mounting.
    var mountDir = await (await ctx.tmpDir).createTemp();
    // Explicitly mount the first partition which is the boot partition.
    var partition = device.startsWith('mmcblk') ? '${device}p1' : '${device}1';
    var result = await ctx.runProcess('mount', [partition, mountDir.path]);
    if (result.exitCode != 0) {
      await ctx.failure('Failed to mount $device', result.stderr);
    }
    return mountDir;
  }
}
