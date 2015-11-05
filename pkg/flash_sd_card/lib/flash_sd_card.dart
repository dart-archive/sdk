// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

import 'src/context.dart';
import 'src/platform_service.dart';

// TODO(sgjesse): Point to the right image.
const String gcsRoot = 'https://storage.googleapis.com';
const String gcsBucket = 'sgjesse-fletch';
const String raspbianImageName = '2015-09-24-raspbian-jessie-fletch';
const String version = '0.1.0-edge.9b6223bf6327d91e42681db8c8a9894d057089d5';

const String imageRootFileName = '$raspbianImageName-$version';
const String imageZipFileName = '$imageRootFileName.zip';
const String imageFileName = '$imageRootFileName.img';

const String gcsImageZipPath = '$gcsRoot/$gcsBucket/$imageZipFileName';

// Original /etc/hosts from Raspberry Pi.
const String originalRaspberryPiHosts = '''
127.0.0.1	localhost
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters

127.0.1.1	raspberrypi
''';

/// Flash a SD card with a Raspbian image.
Future<bool> flashCDCard(List<String> args) async {
  var ctx = new Context(args);

  ctx.log('Starting, OS: ${Platform.operatingSystem}');
  ctx.log('Args: $args');
  ctx.infoln('This program will prepare a SD card for the Raspberry Pi 2');

  // Determine platform.
  PlatformService platformService = new PlatformService(ctx);

  // Find the SD card to flash.
  String sdCardDevice = ctx.sdCardDevice;
  if (sdCardDevice == null) {
    String disk = await platformService.findSDCard();
    if (disk == null) {
      ctx.infoln('No SD card was found');
      ctx.done();
      return false;
    }
    ctx.log('Found SD card $disk');
    sdCardDevice = '/dev/$disk';
    await ctx.readLine(
      'Found the SD card $sdCardDevice. '
      'Press enter to use this card. '
      'This will delete all contents on the card.');
  } else {
    ctx.log('Using SD card from option $sdCardDevice');
    await ctx.readLine(
        'Using the SD card $sdCardDevice. '
        'Press enter to use this card. '
        'This will delete all contents on the card.');
  }

  // Ask for a hostname.
  String hostname = await ctx.readHostname(
      "Enter the name of the device - default is 'fletch': ", 'fletch');

  // Ask for a static IP address.
  String ipAddress = await ctx.readIPAddress(
      'Enter the static IP address you would like the device to have. '
      'Leave it blank to have it assigned via DHCP:', '');

  Directory tmpDir = await ctx.tmpDir;
  String zipFileName = ctx.zipFile;
  var source = Uri.parse(gcsImageZipPath);
  if (zipFileName == null) {
    zipFileName = '${tmpDir.path}/$imageZipFileName';
  }
  File zipFile = new File(zipFileName);
  if (ctx.skipDownload) {
    ctx.infoln('Skipping download');
  } else {
    ctx.infoln('Downloading SD card image');
    await platformService.downloadWithProgress(source, zipFile);
  }

  if (ctx.skipDecompress) {
    ctx.infoln('Skipping decompress.');
  } else {
    ctx.infoln('Decompressing SD card image.');
    await platformService.decompressFile(zipFile, tmpDir);
  }

  var decompressedFile = new File('${tmpDir.path}/$imageFileName');
  ctx.infoln('Unmounting the SD card.');
  await platformService.unmountDisk(sdCardDevice);
  if (ctx.skipWrite) {
    ctx.infoln('Skipping writing image to SD card.');
  } else {
    ctx.infoln('Writing image to SD card.');
    await platformService.ddWithProgress(decompressedFile, sdCardDevice);
  }

  // Make sure the SD card is mounted again.
  ctx.infoln('Mounting the SD card.');
  Directory mountDir = await platformService.mountDisk(sdCardDevice);

  // Sanity check for Raspbian boot partition.
  var bootFiles = await mountDir.list().map((fse) => fse.path).toList();
  ctx.log('Files in ${mountDir.path}: $bootFiles');
  if (!bootFiles.contains('${mountDir.path}/kernel.img')) {
    ctx.infoln('WARNING: This does not look like a Raspbian SD card');
  }

  // All configuration files goes into fletch-configuration on the boot
  // partition.
  Directory configDir =
      new Directory(mountDir.path + '/fletch-configuration');
  await configDir.create();

  // Update the hostname if specified.
  if (hostname.length > 0) {
    await new File(configDir.path + '/hostname').writeAsString(hostname + '\n');
    String hosts = originalRaspberryPiHosts.replaceAll('raspberrypi', hostname);
    await new File(configDir.path + '/hosts').writeAsString(hosts);
  }

  // Update the static IP address if specified.
  if (ipAddress.length > 0) {
    File cmdLineFile = new File(mountDir.path + '/cmdline.txt');
    String cmdLine = await cmdLineFile.readAsString();
    List<String> cmdLineParts = cmdLine.split(' ');
    bool found = false;
    for (int i = 0; i < cmdLineParts.length; i++) {
      if (cmdLineParts[i].startsWith('ip=')) {
        found = true;
        cmdLineParts[i] = 'ip=$ipAddress';
      }
    }
    if (!found) cmdLineParts.insert(cmdLineParts.length - 1, 'ip=$ipAddress');
    await cmdLineFile.writeAsString(cmdLineParts.join(' '));
  }

  // Sync filesystems before unmounting.
  ctx.infoln('Running sync');
  await platformService.sync();

  // Unmount again.
  await platformService.unmountDisk(sdCardDevice);

  // Only remove the mount directory on Linux.
  if (Platform.isLinux) {
    await mountDir.delete();
  }

  // Success.
  ctx.infoln('Finished flashing the SD card. '
             'You can now insert it into the Raspberry Pi');
  ctx.done();
  return true;
}
