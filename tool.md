---
title: Fletch tool details
layout: page
---

# Fletch tool details

## Running code locally and remotely

In the [getting started instructions](index.html) we tried running programs both
on the local PC, and on a remote Raspberry Pi. Are you curious how that works in
details?

When you run a program with ```fletch run``` it always runs in a 'session'. You
can specify the name of the session with an additional argument after run:
```fletch run in session <session name>```. If you omit the session argument,
then the tool defaults to the ```local``` session where the program is run on
the local PC.

The settings for these sessions are defined in configuration files located in
the path ```<user home directory>/<session name>.fletch-settings```. If you take
a look at the remote settings file, you will see this content (exact path and
IP will differ on your PC):

~~~
{
  "packages": "file:///Users/mit/fletch-sdk/internal/fletch-sdk.packages",
  "options": [],
  "constants": {},
  "device_address": "192.168.2.2:12121"
}
~~~

The ```device_address``` tag tells fletch where to locate the VM Agent on your
attached device. If the IP of that device changes, then you need to update this
tag. If the value is omitted or set to null, Fletch will run locally.

## Debugging

Fletch also supports debugging. Let's try to debug the Knight Rider sample.
Start by running the following command in your terminal:

~~~
debug $HOME/fletch-sdk/samples/raspberry_pi/basic/knight-rider.dart in session remote
~~~

You should see the terminal change to:

~~~
Starting session. Type 'help' for a list of commands.

>
~~~

Let's set a breakpoint in the _setLeds method, and start the execution of the
program:

~~~
b _setLeds
r
~~~

We are now inside the _setLeds method. Let's see what the initial state is: Type ```p```. You should see this output

~~~
ledToEnable: 0
this: Instance of 'Lights'
>
~~~

Try to step a few more times (with the ```s``` command), and then print out the
local variable again (with the ```p``` command). You should see ledToEnable
increment up to the numner of LEDs you have, and then you should see it start
decrementing. Pretty neat right!?
