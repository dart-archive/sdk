## 0.3.0

### General changes

* Introduced new product name, Dartino. The command line tool (formerly
 `fletch`) was renamed to `dartino`, and all supporting libraries and packages
 were also renamed.

* Introduced support for ARM Cortex M micro-controllers (MCUs), incl.
 integration with [FreeRTOS](http://www.freertos.org/), the de-facto standard
 real time operating system (RTOS).

* Added board support for the [STM32F746 Discovery board]
(www.st.com/stm32f7-discovery), incl. GPIO and LCD support.

### Libraries and packages

* Added a TLS package, based on [mbed TLS](https://tls.mbed.org/), enabling
 secure sockets via Transport Layer Security (TLS) and Secure Sockets Layer
 (SSL).

* Added new MQTT package for the [MQTT protocol](http://mqtt.org/). Note this
 requires a third-party library to be compiled, see [the documentation]
 (https://dartino.github.io/api/mqtt/index.html) for details.

* Changed the GPIO package public interface. Changed the existing
 implementations for Raspberry Pi 2. Added an implementation for the STM32
 board.

## 0.2.0

* Added a getting started script that automates the creation of the Raspberry Pi 2
 SD card.

* Added network discovery support making it easier to run Dartino programs on
 Raspberry Pi 2 devices connected over the network.

* Added generated API documentation. Included in the SDK download in the docs
 folder, and online at https://dartino.github.io/api/.

* Many smaller fixes.

## 0.1.0

* First SDK release, includes the core runtime, compiler, and a few select
 libraries.
