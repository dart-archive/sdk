## 0.5.0 (5 July 2016)

### Tool changes

* Almost complete command line debugger (`dartino debug <source file>`).

* Analyzer support from the dartino command (`dartino analyze <source file>`).

* New snapshot format (no user-facing changes).

* Analytics for both command line and Atom.

### Runtime changes

* Out-of-memory / no-progress-on-GC detection.

* Preemptive scheduling of Dartino processes on FreeRTOS.

### Library changes

* TLS & UDP integrated into the network stack for the STM32F746G Discovery
 board.

* I2C support for the STM32F746G Discovery board.

* I2C drivers for sensors on the X-NUCLEO-IKS01A1 expansion board for STM32
 Nucleo.

* Initial support for STM32F411RE Nucleo board (GPIO and UART).

* Polling mode ADC support on both STM32F746G Discovery and STM32F411RE Nucleo
 boards.

* Improved API documentation for both core libraries and support packages.

## 0.4.0 (19 May 2016)

### General changes

* Support for call-backs from C back into Dartino. For an example, see:
 `/dartino-sdk/samples/general/native-interop/`


* Networking support on the STM F746 board. For examples, see:
`/dartino-sdk/samples/stm32f746g-discovery/weather-service.dart` and `/dartino-sdk/samples/stm32f746g-discovery/http_json_sample.dart`

## 0.3.0 (23 February 2016)

### General changes

* Introduced new product name, Dartino. The command line tool (formerly
 `fletch`) was renamed to `dartino`, and all supporting libraries and packages
 were also renamed.

* Introduced support for ARM Cortex M micro-controllers (MCUs), incl.
 integration with [FreeRTOS](http://www.freertos.org/), the de-facto standard
 real time operating system (RTOS).

* Added board support for the [STM32F746 Discovery board]
(http://www.st.com/stm32f7-discovery), incl. GPIO and LCD support.

### Libraries and packages

* Added a TLS package, based on [mbed TLS](https://tls.mbed.org/), enabling
 secure sockets via Transport Layer Security (TLS) and Secure Sockets Layer
 (SSL).

* Added new MQTT package for the [MQTT protocol](http://mqtt.org/). Note this
 requires a third-party library to be compiled, see [the documentation]
 (http://dartino.github.io/api/mqtt/mqtt-library.html) for details.

* Changed the GPIO package public interface. Changed the existing
 implementations for Raspberry Pi 2. Added an implementation for the STM32
 board.

## 0.2.0 (16 November 2015)

* Added a getting started script that automates the creation of the Raspberry Pi
 2 SD card.

* Added network discovery support making it easier to run Dartino programs on
 Raspberry Pi 2 devices connected over the network.

* Added generated API documentation. Included in the SDK download in the docs
 folder, and online at https://dartino.github.io/api/.

* Many smaller fixes.

## 0.1.0 (7 October 2015)

* First SDK release, includes the core runtime, compiler, and a few select
 libraries.
