// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

import 'src/context.dart';
import 'src/platform_service.dart';

const String gcsRoot = 'https://storage.googleapis.com';
const String gcsBucket = 'fletch-archive';

const String imageRootFileName = 'fletch_raspbian';
const String imageFileName = '$imageRootFileName.img';
const String imageZipFileName = '$imageFileName.zip';

// Original /etc/hosts from Raspberry Pi.
const String originalRaspberryPiHosts = '''
127.0.0.1	localhost
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters

127.0.1.1	raspberrypi
''';

/// Check if a version is a bleeding edge version.
bool isEdgeVersion(String version) => version.contains('-edge.');

/// Check if a version is a dev version.
bool isDevVersion(String version) => version.contains('-dev.');

/// Flash an SD card with a Raspbian image.
Future<bool> flashCDCard(List<String> args) async {
  var ctx = new Context(args);

  ctx.log('Starting, OS: ${Platform.operatingSystem}');
  ctx.log('Args: $args');
  if (ctx.configureNetworkOnly) {
    ctx.infoln('This program will update the network configuration on a '
               'Fletch Raspberry Pi 2 SD card.');
  } else {
    ctx.infoln('This program will prepare an SD card for '
               'Fletch on the Raspberry Pi 2.');
  }

  // Determine platform.
  PlatformService platformService = new PlatformService(ctx);

  // Determine the download URL for the image.
  String imageUrl = ctx.imageUrl;
  if (ctx.imageUrl == null) {
    String version = await ctx.version;
    String gcsPath;
    if (isEdgeVersion(version)) {
      ctx.infoln('WARNING: For bleeding edge a fixed image is used.');
      // For edge versions download a well known version for now.
      var knownVersion = '0.1.0-edge.d8cabb9332b9a1fb063f55fca18d8b87320e863a';
      gcsPath =
          'channels/be/raw/$knownVersion/sdk';
    } else if (isDevVersion(version)) {
      // TODO(sgjesse): Change this to channels/dev/release at some point.
      gcsPath = 'channels/dev/raw/$version/sdk';
    } else {
      await ctx.failure('Stable version not supported. Got version $version.');
    }
    imageUrl = '$gcsRoot/$gcsBucket/$gcsPath/$imageZipFileName';
  }

  // Find the SD card to flash.
  String sdCardDevice = ctx.sdCardDevice;
  if (sdCardDevice == null) {
    String disk = await platformService.findSDCard();
    if (disk == null) {
      ctx.infoln('\nNo SD card was found. In some configurations the auto '
                 'detection mechanism does not work.\nIn that case you can use '
                 'the option --sd-card to specify the SD card device, e.g.:');
      if (Platform.isLinux) {
        ctx.infoln('\n  \$ flash_sd_card --sd-card /dev/sdc\n');
      } else {
        ctx.infoln('\n  \$ flash_sd_card --sd-card /dev/rdisk2\n');
      }
      ctx.done();
      return false;
    }
    ctx.log('Found SD card $disk');
    sdCardDevice = '/dev/$disk';
    String info = await platformService.diskInfo(sdCardDevice);
    if (ctx.configureNetworkOnly) {
      await ctx.readLine(
          '\nFound the SD card $sdCardDevice.\n$info\n'
          'This will update the network configuration. '
          'Press Enter to use this card (Ctrl-C to cancel).');
    } else {
      await ctx.readLine(
          '\nFound the SD card $sdCardDevice.\n$info\n'
          'This will delete all contents on the card. '
          'Press Enter to use this card (Ctrl-C to cancel).');
    }
  } else {
    String info = await platformService.diskInfo(sdCardDevice);
    ctx.log('Using SD card from option $sdCardDevice');
    if (ctx.configureNetworkOnly) {
      await ctx.readLine(
          '\nUsing the SD card $sdCardDevice.\n$info\n'
          'This will update the network configuration. '
          'Press Enter to use this card (Ctrl-C to cancel).');
    } else {
      await ctx.readLine(
          '\nUsing the SD card $sdCardDevice.\n$info\n'
          'This will delete all contents on the card. '
          'Press Enter to use this card (Ctrl-C to cancel).');
    }
  }

  // Ask for a hostname.
  String hostname = await ctx.readHostname(
      "Enter the name of the device - default is 'fletch' "
      "(press Enter to accept): ", 'fletch');

  // Ask for a static IP address.
  String ipAddress = await ctx.readIPAddress(
      'Enter the static IP address you would like the device to have. '
      'Leave it blank to have it assigned via DHCP: ', '');

  Directory mountDir;
  if (ctx.configureNetworkOnly) {
    // Make sure the SD card is mounted.
    mountDir = await platformService.mountDisk(sdCardDevice);
  } else {
    Directory tmpDir = await ctx.tmpDir;
    String zipFileName = ctx.zipFileName;
    var source = Uri.parse(imageUrl);
    if (zipFileName == null) {
      zipFileName = '${tmpDir.path}/$imageZipFileName';
    }
    File zipFile = new File(zipFileName);
    if (ctx.skipDownload) {
      ctx.infoln('Skipping download.');
    } else {
      ctx.infoln('Downloading SD card image.');
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
    mountDir = await platformService.mountDisk(sdCardDevice);
  }

  // Sanity check for Raspbian boot partition.
  var bootFiles = await mountDir.list().map((fse) => fse.path).toList();
  ctx.log('Files in ${mountDir.path}: $bootFiles');
  if (!bootFiles.contains('${mountDir.path}/kernel.img')) {
    ctx.infoln('WARNING: This does not look like a Raspbian SD card.');
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
  ctx.infoln('Running sync.');
  await platformService.sync();

  // Unmount again.
  await platformService.unmountDisk(sdCardDevice);

  // Only remove the mount directory on Linux.
  if (Platform.isLinux) {
    await mountDir.delete();
  }

  // Success.
  ctx.infoln('Finished flashing the SD card. '
             'You can now insert it into the Raspberry Pi 2.');
  ctx.done();
  return true;
}
