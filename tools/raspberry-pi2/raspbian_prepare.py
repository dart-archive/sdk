#!/usr/bin/env python
#
# Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.
#

# Prepares a raspbian image to support fletch. We use qemu to edit the image
# since this allows us to run commands and push data to the image without using
# sudo. This script will "edit" the image in place, so take a copy before using.

import optparse
import os
import pexpect
import pxssh
import sys
import time

HOSTNAME = 'localhost'
USERNAME = 'pi'
PASSWORD = 'raspberry'
KERNEL = 'third_party/raspbian/kernel/kernel-qemu'
CONFIG = 'tools/raspberry-pi2/raspbian-scripts/fletch-configuration'
QEMU = 'third_party/qemu/linux/qemu/qemu-system-arm'
PORT = 10022

def Options():
  result = optparse.OptionParser()
  result.add_option("--agent",
                    default=None,
                    help="The arm agent deb file.")
  # We assume that this file has been patched to remove the /etc/ld.so.preload
  # entries and that /etc/fstab entries are also fixed. We will remove the
  # comment markers in these files in this script.
  result.add_option("--image",
                    default=None,
                    help="The raspbian image file.")
  result.add_option("--src",
                    default=None,
                    help="The source tarball that we ship with the image.")

  (options, args) = result.parse_args()
  return options

def InstallAgent(qemu, agent):
  deb_dst = '/tmp/agent.deb'
  qemu.put_file(agent, deb_dst)
  qemu.run_command('sudo sudo dpkg -i %s' % deb_dst)
  qemu.run_command('rm %s' % deb_dst)
  # This will fail, but it lets us validate that the binary was installed.
  qemu.run_command('fletch-vm --version')

def InstallConfig(qemu):
  config_dst = '/tmp/fletch-configuration'
  qemu.put_file(CONFIG, config_dst)
  qemu.run_command('sudo cp /tmp/fletch-configuration /etc/init.d')
  qemu.run_command('sudo chown root:root /etc/init.d/fletch-configuration')
  qemu.run_command('sudo chmod 755 /etc/init.d/fletch-configuration')
  qemu.run_command('sudo insserv fletch-configuration')
  qemu.run_command('sudo update-rc.d fletch-configuration enable')

def InstallSrcTarball(qemu, src):
  src_dst = os.path.join('/home', 'pi', os.path.basename(src))
  qemu.put_file(src, src_dst)

def FixRasbianConfigs(qemu):
  # This removes the comment markers created by:
  #   tools/raspberry-pi2/qemufy-image.sh
  qemu.run_command('sudo sed -i "/mmcblk/s/#//g" /etc/fstab')
  qemu.run_command('sudo sed -i "s/#//g" /etc/ld.so.preload')

def Main():
  options = Options()
  with QemuSession(options.image, KERNEL) as qemu:
    InstallAgent(qemu, options.agent)
    InstallConfig(qemu)
    InstallSrcTarball(qemu, options.src)
    FixRasbianConfigs(qemu)

class QemuSession(object):
  def __init__(self, image, kernel):
    self.image = image
    self.kernel = kernel

  def __enter__(self):
    cmd = [QEMU, '-kernel', self.kernel, '-cpu', 'arm1176', '-m',
           '256', '-M', 'versatilepb', '-no-reboot', '-nographic', '-append',
          '"root=/dev/sda2 panic=1 vga=normal rootfstype=ext4 '
          'rw console=ttyAMA0"', '-hda', self.image,
          '-net', 'user,hostfwd=tcp::10022-:22', '-net', 'nic']
    print 'Starting qemu with:\n%s' % ' '.join(cmd)
    env = os.environ.copy()
    self.process = pexpect.spawn(' '.join(cmd))
    # Put this into a log file, see issue 285
    self.logfile = open('.qemu_log', 'w')
    self.process.logfile = self.logfile
    # Give the vm some time to bootup.
    time.sleep(50)
    # Try connection multiple times, the time it takes to boot varies a lot.
    for x in xrange(20):
      try:
        # Get any output from qemu to the stdout
        self.process.read()
      except:
        # If nothing is happening, i.e., we are at the login screen, this call
        # throws
        pass
      sys.stdout.flush()
      print 'Connection attempt %s' % x
      ssh = pxssh.pxssh()
      ssh.SSH_OPTS += " -oStrictHostKeyChecking=no"
      ssh.SSH_OPTS += " -oUserKnownHostsFile=/dev/null"
      try:
        ssh.login(HOSTNAME, USERNAME, password=PASSWORD, port=PORT)
        self.ssh = ssh
        # Validate connection.
        self.run_command('uptime')
        break
      except pxssh.ExceptionPxssh, e:
        print "pxssh failed on login."
        print str(e)
      except:
        print 'qemu not up yet'
      time.sleep(10)
    if not self.ssh or not self.ssh.isalive():
      # Make sure the output of qemu is forced to file
      self.process.read()
      self.logfile.close()
      raise Exception('The ssh connection could not be initialized')
    return self

  def run_command(self, cmd):
    assert(self.process.isalive())
    assert(self.ssh.isalive())
    print 'Running cmd:\n%s' % cmd
    self.ssh.sendline(cmd)
    self.ssh.prompt()
    result = self.ssh.before
    print 'Result: \n%s' % result
    return result

  # pxssh do not support scp
  def put_file(self, src, dst):
    assert(self.process.isalive())
    assert(self.ssh.isalive())
    options = '-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null'
    cmd = 'scp %s -P %s %s %s@%s:%s' % (options,
                                        PORT,
                                        src,
                                        USERNAME,
                                        HOSTNAME,
                                        dst)
    child = pexpect.spawn(cmd)
    print 'Running: %s' % cmd
    child.expect(['password:', r"yes/no"], timeout=7)
    child.sendline(PASSWORD)
    data = child.read()
    print data
    child.close()

  def __exit__(self, *_):
    # We can't cleanly shut down, since we can't run shutdown -r after
    # we have reinstated /etc/ld.so.preload
    self.run_command('sync')
    try:
      self.run_command('exit')
    except:
      # We expect this to fail, the prompt will not come after we call exit
      pass

    for x in xrange(10):
      print 'Waiting for qemu to exit, try %s' % (x + 1)
      time.sleep(1)
      if not self.process.isalive():
        print 'Qemu shut down nicely, our work here is done'
        return
    # The process did not shut down, kill it
    print 'Qemu did not shut down nicely, killing it'
    self.process.terminate(force=True)
    self.process.read()
    self.logfile.close()
    # We should actually throw here, but since we can't nicely shut down we
    # allow this for now, see issue 277

if __name__ == '__main__':
  sys.exit(Main())
