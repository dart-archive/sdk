---
title: Fletch project
layout: page
---

# The Fletch project

Fletch is an **experimental** project to enable highly productive development
for embedded devices. It is powered by the [Dart
language](https://www.dartlang.org/docs/dart-up-and-running/ch02.html) and a
fast, lean runtime.

This page will take you through getting the Fletch platform installed on your
local developer PC so that you can run and write Fletch programs that target
embedded devices. Note that the current early version of Fletch only supports a
single embedded device -- the Raspberry Pi 2 -- and the only supported
client operating systems supported for development are MacOS and Linux (sorry,
no Windows support).

If you just want to get a look at what Fletch programs look like, take a peek at
our [samples page](samples.html).

* [What you will need](#what-you-will-need)
* [Installing the SDK](#installing-the-sdk)
* [Running your first program](#running-your-first-program)
* [Preparing your Raspberry Pi 2](#preparing-your-raspberry-pi-2)
* [Running on the Raspberry Pi 2](#running-on-the-raspberry-pi-2)
* [Next steps](#next-steps)

## What you will need

To develop embedded programs with Fletch, you will need the following:

* A developer PC where you write the programs

* A Raspberry Pi 2 embedded computer for running the programs

* A MicroSD card and some kind of SD card reader to hold the operating system for
 the Raspberry Pi 2

* An extra network plug on your developer PC, or a USB network adapter + an
 Ethernet cable you can connect between your developer PC and your Raspberry Pi
 2

* Optional: A breadboard and a collection of components for running some of
 the samples (will be discussed later)

![What you need photo](https://storage.googleapis.com/fletch-archive/images/setup.jpg)

## Installing the SDK

First download the SDK. This is available as a '.zip' archive; pick the one that
matches the OS of the PC you will be using for development:

* [MacOS, 32-bit](https://storage.googleapis.com/fletch-archive/channels/dev/release/latest/sdk/fletch-sdk-macos-ia32-release.zip)
* [MacOS, 64-bit](https://storage.googleapis.com/fletch-archive/channels/dev/release/latest/sdk/fletch-sdk-macos-x64-release.zip)
* [Linux, 32-bit](https://storage.googleapis.com/fletch-archive/channels/dev/release/latest/sdk/fletch-sdk-linux-ia32-release.zip)
* [Linux, 64-bit](https://storage.googleapis.com/fletch-archive/channels/dev/release/latest/sdk/fletch-sdk-linux-x64-release.zip)

Unzip this, and make sure that the Fletch command is in the path by typing the
below in a terminal window:

~~~
cd $HOME
unzip ./Downloads/fletch-sdk-macos-x64-release.zip
export "PATH=$PATH:$HOME/fletch-sdk/bin"
~~~

Test if the Fletch program works; it should print a version number to the
console:

~~~
fletch --version
~~~

## Running your first program

Let’s go ahead and run our first Fletch program. This is a simple program that
prints Hello. In your command line type:

~~~
cd $HOME/fletch-sdk/samples/general/
fletch run hello.dart
~~~

You should see a message that says ```Created settings file...```, and then a
message like this (the machine name in the end will be different):

~~~
Hello from Darwin running on michael-pc2.
~~~

Try to open `hello.dart` in your favorite editor. We recommend the [Atom
editor](https://atom.io/) by Github with the [Dart
plugin](https://github.com/dart-atom/dartlang/). Pretty easy to read, right?
(Note: you will get some Analyzer warnings in Atom as we don't fully support it
yet. You can ignore those.)

But what actually happened when we asked the ```fletch``` command to run
`hello.dart`? By default ```fletch``` is connected to a local session,
which is connected to a local VM (Virtual Machine) running on your developer PC.
When you ask ```fletch``` to run the program, it compiles the program to byte
code, and then passes it to the local Fletch VM for execution. The VM passes
back the result, and fletch prints it to your command line.

![Fletch architecture diagram](https://storage.googleapis.com/fletch-archive/images/Fletch-architecture.png)

Now let’s get things running on your Raspberry!

## Preparing your Raspberry Pi 2

*Note*: If you already have a working Raspberry Pi 2 with a recent Raspbian
image, then you can skip to step 2.

### Step 1: Raspbian operating system

In this first step we will get a copy of the Raspbian operating system, and get
it written to your SD card. You can skip this step if you already have Raspbian
running. Otherwise follow these steps to get the image installed:

* Download the zip file containing 'Raspbian Jessie' from the [Raspbian download
 page](https://www.raspberrypi.org/downloads/raspbian/).
* Unzip the file by typing this in a termnal window:
  * On Mac: ```ditto -x -k 2015-09-24-raspbian-jessie.zip .```
  * On Linux: ```unzip 2015-09-24-raspbian-jessie.zip```
* Follow the steps to [get the .img file onto your SD
 Card](https://www.raspberrypi.org/documentation/installation/installing-images/README.md).

### Step 2: Configure the IP address for the Raspberry Pi 2

We need to enable IP communication between your developer PC and your Raspberry
Pi. You can either connect your Raspberry to your router (via a cable or WiFi),
or you can add a second Ethernet adapter to your developer PC and connect to the
Raspberry Pi directly via an Ethernet cable.

There are several ways you can configure the IP number of the Raspberry:

* *Option 1*: If you have your Raspberry connected to a monitor, then you can use this approach:
  * Boot the Raspberry
  * After boot enter ```sudo ip show addr``` in a terminal prompt on the Raspberry.Note down the IP as we will be using it below.
  * If it does not have an IP, configure a static IP.

* *Option 2*: If you are on a Linux developer PC, you can also configure the image directly from your developer PC.
  * Mount the SD card
  * Enter the following in a console: ```$HOME/fletch-sdk/platforms/raspberry-pi2/setup-ip.sh <path to SD card's boot partition>```

* *Option 3*: If you are on a Mac developer PC, you can connect directly to the Raspberry Pi via an USB Network adapter connected to the Raspberry Pi via a networking cable, and the following configuration steps:
  * Turn off your Raspberry Pi
  * Open System Preferences and pick the Network icon
  * Plug the USB Ethernet adapter into your Mac
  * Change the IPv4 option to ```Manually```
  * Enter the IP Address ```192.168.2.1```
  * Go back to System Preferences and pick the Sharing icon. Enable sharing of Internet for the USB Ethernet Adapter
  * Turn your Raspberry Pi back on
  * After a little while you should be able to ping the Raspberry Pi at ```192.168.2.2```

### Step 3: Install Fletch binaries

**Note**: In the steps below, replace ```192.168..``` with whatever IP address you configured above.

The last step is to install the Fletch runtime on the Raspberry Pi (see the
right-hand side of the architecture diagram above). Use the following commands.

A. Copy the fletch-agent package to the Raspberry Pi 2 (the default password for
user 'pi' on Raspbian is 'raspberry'):

~~~
cd $HOME/fletch-sdk
scp ./platforms/raspberry-pi2/fletch-agent*.deb pi@192.168..:/home/pi/
~~~

B. Install the package:

~~~
ssh pi@192.168.. sudo dpkg --install /home/pi/fletch-agent*.deb
~~~

You should see something like ```Unpacking fletch-agent...``` on your screen.

## Running on the Raspberry Pi 2

The Fletch platform is now available on the Raspberry Pi 2. Let’s make our Hello
program run again, this time on the Raspberry Pi 2. Type the following command
on your local developer PC:

~~~
cd $HOME/fletch-sdk/
fletch run ./samples/general/hello.dart in session remote
~~~

The first time you run in the remote session you will be asked to enter the IP
address. Enter the IP you picked in the previous step, e.g. ```192.168.2.2```.

You should then see the following output on your screen:

~~~
Hello from Linux running on raspberrypi.
~~~

Did you notice the difference? As before Fletch compiled the hello.dart program
to byte code, but this time rather than passing it to the local VM via the local
session it passed it to the Raspberry Pi via the remote session. On the
Raspberry Pi, the Fletch VM Agent made sure that a VM (Virtual Machine) was spun
up, and the program was executed on it. The result of the program (the printing
to the console) was passed back by the VM to the Fletch command on the developer
PC, and it was printed to the local console.

## Next steps

Ready for some more fun? Take a look at our [samples](samples.html), and read
more about the [Fletch tool](tool.html).

And don’t forget to send us some [feedback](feedback.html), and ask some
[questions](faq.html).
