The instructions in [getting started page](index.html) configures the Raspberry
Pi 2 SD card image using an automated script. If you prefer to create the image
manually, you can use these steps:

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

### Step 3: Install Dartino binaries

**Note**: In the steps below, replace ```192.168..``` with whatever IP address you configured above.

The last step is to install the Dartino runtime on the Raspberry Pi (see the
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
