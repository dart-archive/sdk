---
title: Fletch project samples
layout: page
---

# Fletch project samples

We have a number of sample programs available in the ```samples/raspberry_pi```
folder. Let’s take a look at the code, and get familiar with the platform.


* [blinky.dart](#blinky)
  * The 'hello world' of embedded: Blink an LED
  * Requires a Raspberry Pi 2

* [buzzer.dart](#buzzer)
  * Controlling GPIO input and output pins
  * Requires a Raspberry Pi 2 and some components

* [door-bell.dart](#door-bell)
  * Using GPIO events
  * Requires a Raspberry Pi 2 and some components

* [knight-rider.dart](#knight-rider)
  * Structuring larger programs with classes
  * Requires a Raspberry Pi 2 and some components

* [accelerometer.dart](#sense-hat-accelerometer)
  * Communicating with a 'Sense HAT shield'
  * Requires a Raspberry Pi 2 and a [Sense HAT](https://www.raspberrypi.org/products/sense-hat/)

* [ticker.dart](#ticker)
  * Outputing text messages via a running "news ticker"
  * Requires a Raspberry Pi 2 and a [Sense HAT](https://www.raspberrypi.org/products/sense-hat/)

## Blinky ##

Embedded devices are most commonly used to collect data and perform some kind of
control task via attached sensors and output devices such as LEDs. Take a look
at the ```blinky.dart``` program located in the
```samples/raspberry_pi/basic/``` folder. This blinks the Raspberry Pi 2
on-board LED.

First the program initializes the RaspberryPi helper object:

~~~
RaspberryPi pi = new RaspberryPi();
pi.leds.activityLED.setMode(OnboardLEDMode.gpio);
~~~

Next, it simply loops and alternates between turning the led on and off:

~~~
while (true) {
  pi.leds.activityLED.on();
  sleep(500);
  pi.leds.activityLED.off();
  sleep(500);
}
~~~

Pretty easy, right!?

## Buzzer

Let's expand on the previous sample by wiring up a small custom circuit. We will
use a [breadboard](http://www.instructables.com/id/How-to-use-a-breadboard/) for
fast iteration.

Start by building a circuit resembling [this
schematic](https://storage.googleapis.com/fletch-archive/images/buzzer-schematic.png).

We will be communicating with the components on the breadboard using a
[GPIO](https://en.wikipedia.org/wiki/General-purpose_input/output) (general
purpose input/output) interface. First we need to configure the GPIO pins for
the components we wired up (full runnable code located in
```samples/raspberry_pi/basic/buzzer.dart```):

~~~
import 'package:gpio/gpio.dart';

main() {
  // GPIO pin constants.
  const int button = 16;
  const int speaker = 21;
~~~

Notice how we are using pins 16 and 21. Those pin numbers are based on the
connection points shown in the schematic, and the [pinout for the Raspberry Pi
2](http://www.raspberry-projects.com/pi/pi-hardware/raspberry-pi-2-model-b/rpi2-model-b-io-pins).

Next, we need to tell GPIO which pins we intend to write to (i.e., use as
output), and which we intend to read from (i.e., use as input):

~~~
RaspberryPi pi = new RaspberryPi();
PiMemoryMappedGPIO gpio = pi.memoryMappedGPIO;
gpio.setMode(button, Mode.input);
gpio.setMode(speaker, Mode.output);
~~~

Finally, we simply spin in an internal loop and map the state of the button to
the speaker, i.e. when we see a high signal on the button we set a high signal
on the speaker and vice versa.

~~~
while (true) {
  bool buttonState = gpio.getPin(button);
  gpio.setPin(speaker, buttonState);
}
~~~

## Door bell

In the buzzer sample we spun in an eternal loop to sound out speaker. Often it
can be more convenient to wait for a certain state to occur. This is supported
via GPIO events. Let try to build a small door bell.

First we need to configure GPIO for events. We configure the pins as before, and
then enable a trigger on the button:

~~~
// Initialize Raspberry Pi and configure the pins.
RaspberryPi pi = new RaspberryPi();
SysfsGPIO gpio = pi.sysfsGPIO;

// Initialize pins.
gpio.exportPin(speaker);
gpio.setMode(speaker, Mode.output);
gpio.exportPin(button);
gpio.setMode(button, Mode.input);
gpio.setTrigger(button, Trigger.both);
~~~

Next, we simply wait for the button to be pressed (i.e., for the GPIO pin of the
button to go to 'true'):

~~~
while (true) {
  // Wait for button press.
  gpio.waitFor(button, true, -1);

  ...
  }
}
~~~

And then we sound the bell:

~~~
// Sound bell.
for (var i = 1; i <= 3; i++) {
  gpio.setPin(speaker, true);
  sleep(100);
  gpio.setPin(speaker, false);
  sleep(500);
}
~~~

## Knight rider

In all the previous samples we relied on a very simple program structure: A few
lines of initialization code, and then a small eternal loop in which we had a
few more lines of code. For our next sample we are going to explore a slightly
larger program to illustrate how the Dart programming language allows us to
structure our program using classes and encapsulation.

We are going to build a small running light. Remember
[KITT](https://www.youtube.com/watch?v=Mo8Qls0HnWo), the car from the Knight
Rider show? Let's try to [replicate those
lights](https://storage.googleapis.com/fletch-archive/images/knight-rider.mp4).

The full program is available in
```samples/raspberry_pi/basic/knight-rider.dart```. Let's step through how it's
built.

First we will create a ```Lights``` helper class. This class will contain all
the core functionality required for managing the LEDs on the breadboard that we
will be animating. Initially let's define a variable containing a list of
integers containing the GPIO pins of all the connected LEDs, and a variable
containing a GPIO manager. Note that the GPIO variable starts with an
underscore; this is the Dart syntax for declaring a private variable that is
encapsulated to the implementation of the class.)

~~~
class Lights {
  final GPIO _gpio;
  final List<int> leds;

  Lights(this._gpio, this.leds);
  ...
}
~~~

Next, let's implement a small helper function that we can call with a LED number
(e.g., 2), and which then turns LED number 2 in the LED chain on and turns all
the other LEDs in the chain off:

~~~
// Sets LED [ledToEnable] to true, and all others to false.
void _setLeds(int ledToEnable) {
  var state;

  for (int i = 0; i < leds.length; i++) {
    bool state = (i == ledToEnable);
    _gpio.setPin(leds[i], state);
  }
}
~~~

Next, we need to have the lights first move from the left to the right, and then
from the right to the left. We will do this in another two methods that simply
run in a for loop either from 0 to the number or LEDs, or the opposite, and then
call the helper function above:

~~~
// Iterates though the lights in increasing order, and sets the LEDs using
// a helper function. Pauses [waitTime] milliseconds before returning.
void runLightLeft(int waitTime) {
  for (int counter = 0; counter < leds.length; counter++) {
    _setLeds(counter);
    sleep(waitTime);
  }
}

// Iterates though the lights in decreasing order, and sets the LEDs using
// a helper function. Pauses [waitTime] milliseconds before returning.
void runLightRight(int waitTime) {
  for (int counter = leds.length - 1; counter >= 0; counter--) {
    _setLeds(counter);
    sleep(waitTime);
  }
}
~~~

Finally, we just need a small Main function to to hold the GPIO pins, to
initialize our Lights helper class, and to call the lights methods, and we are
done!

~~~
main() {
  // Initialize Raspberry Pi.
  RaspberryPi pi = new RaspberryPi();

  // Array constant containing the GPIO pins of the connected LEDs.
  // You can add more LEDs simply by extending the list. Make sure
  // the pins are listed in the order the LEDs are connected.
  List<int> leds = [26, 19, 13, 6];

  // Initialize the lights controller class.
  Lights lights = new Lights(pi.memoryMappedGPIO, leds);
  lights.init();

  // Alternate between running left and right in a continuous loop.
  const int waitTime = 100;
  while (true) {
    lights.runLightLeft(waitTime);
    lights.runLightRight(waitTime);
  }
}
~~~

## Sense HAT Accelerometer

In the above samples we connected a breadboard to our Raspberry Pi 2 as a way of
extending it. Another way of extending is adding a 'shield'. These are add-ons
that are plugged on top of the Raspberry. One such shield is the Sense HAT, a
shield that contains an LED matrix display and large collection of sensors such
as a gyroscope, an accelerometer, and a humidity sensor. The Sense HAT is so
powerful that it will be [going into
space!](https://www.raspberrypi.org/blog/astro-pi/)

![Sense HAT photo](https://storage.googleapis.com/fletch-archive/images/sense-hat.jpg)

In this sample we are going to use the accelerometer to sense which direction
the board is pointing in, and then display that direction using the LED matrix
display. Full code is in
```samples/raspberry_pi/sense_hat/accelerometer/accelerometer.dart```.

We start with a helper function that will draw a color bar on the display. It
will take a direction argument (north, west, etc.), and a segment number from 0
to 3 telling it how far from the center it should draw. Calling it with segment
1 and north, for example, will draw this bar show on the left, and segment 0 and
east will draw the bar shown on the right:

~~~
_ _ _ _ _ _ _ _          _ _ _ _ _ _ _ _
_ _ _ _ _ _ _ _          _ _ _ _ _ _ _ _
_ _ x x x x _ _          _ _ _ _ _ _ _ _
_ _ _ _ _ _ _ _          _ _ _ _ x _ _ _
_ _ _ _ _ _ _ _          _ _ _ _ x _ _ _
_ _ _ _ _ _ _ _          _ _ _ _ _ _ _ _
_ _ _ _ _ _ _ _          _ _ _ _ _ _ _ _
_ _ _ _ _ _ _ _          _ _ _ _ _ _ _ _
~~~

The implementation of the function is here:

~~~
void drawSegment(SenseHatLEDArray ledArray,
                 Direction direction,
                 int segment,
                 {Color color}) {
  const defaultSegmentColor =
      const <Color>[Color.white, Color.green, Color.blue, Color.red];

  if (color == null) color = defaultSegmentColor[segment];
  var length = (segment + 1) * 2;
  var info = segmentData[direction];
  var x = info.origin.x + info.direction.x * segment;
  var y = info.origin.y + info.direction.y * segment;
  for (int i = 0; i < length; i++) {
    ledArray.setPixel(x, y, color);
    x += info.step.x;
    y += info.step.y;
  }
}
~~~

This function uses ```ledArray.setPixel``` to manage the LED display. This
method is implemented by the Fletch Sense HAT library (see
```pkg/raspberry_pi/lib/sense_hat.dart```), which provides a convenient
interface for the Sense HAT.

We will use the same library to read from the accelerometer:

~~~
while (true) {
  // Read the accelerometer and update the display it one of the values
  // changed.
  var accel = hat.readAccel();
  var p = trimValue(accel.pitch);
  var r = trimValue(accel.roll);
  if (p != pitch || r != roll) {
    pitch = p;
    roll = r;
    draw();
  }
}
~~~

Lastly, we connect the reading of the pitch and roll values to drawing of a
directional bar in the draw function:

~~~
void draw() {
  hat.clear();
  if (pitch == 0 && roll == 0) {
    drawSegment(hat.ledArray, Direction.north, 0);
    drawSegment(hat.ledArray, Direction.south, 0);
  } else {
    if (pitch != 0) {
      drawSegment(
        hat.ledArray,
        pitch < 0 ? Direction.north : Direction.south,
        pitch.abs());
    }
    if (roll != 0) {
      drawSegment(
        hat.ledArray,
        roll < 0 ? Direction.west : Direction.east,
        roll.abs());
    }
  }
}
~~~

## Ticker

An effective and iconic way to output an arbitrary text message from an embedded
device is the classic "ticker". It runs the message through the screen (in this
case, the Sense HAT's LED matrix) from right to left, thus working around the
very limited screen estate.

<iframe width="560" height="315"
  src="https://www.youtube.com/embed/tg27sAVNx8U?rel=0"
  frameborder="0" allowfullscreen></iframe>

The code is in ```samples/raspberry_pi/sense_hat/ticker/```, split into two
separate files.

In `font.dart` we find the Font class. This represents a bitmap font that can
render itself on the Sense HAT LED matrix. The bulk of the code is in the
`display()` function which uses simple arithmetic and bitwise operations to
extract the font pixel data from a binary representation. The function takes
the SenseHatLEDArray object (which it redraws), the message string, and the
offset in pixels.

The same file also provides `defaultFont`, an instance of the Font class and
a 6x5 font specially crafted for Fletch. You can use it in your own projects.

In `ticker.dart`, all we need to do is the animation. We increment the
offset once every 70 milliseconds and re-render. This gives the impression of
a sliding text message.

~~~
main() {
  // Instantiate the Sense HAT API.
  var hat = new SenseHat();

  // Start the ticker with negative offset so that the text starts
  // from off to the right.
  var offset = -hat.ledArray.width;
  var message = "Hello World!";
  while (true) {
    defaultFont.display(hat.ledArray, message, offset);
    offset += 1;
    if (offset > message.length * defaultFont.width) {
      // Reset.
      offset = -hat.ledArray.width;
    }
    os.sleep(70);
  }
}
~~~

We could update the message text with readings from sensors, current time, or
anything else we needed to convey to the user.
