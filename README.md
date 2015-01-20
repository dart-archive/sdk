# Fletch

Fletch is an **experimental** system that makes it possible to implement highly concurrent programs
in the Dart programming language. To make it easier to reason about such programs, Fletch comes with a
virtual machine implementation that encourages synchronous operations over asynchronous ones - and 
enables lots of user-level threads to be blocked without holding on to too many resources.

Fletch is very much incomplete. We'd be very happy to hear about things that work well and areas that need 
more work, but don't expect to be able to build products on top of it.


## Contributing

To give us feedback, please
[file issues on GitHub](https://github.com/dart-lang/fletch/issues) or join our
[mailing list](https://groups.google.com/forum/#!forum/fletch) and post there.
We also welcome contributions; just sign our
[CLA](https://developers.google.com/open-source/cla/individual),
fork our repository, and start sending us pull requests.


## License

Fletch is available under the *Modified BSD license*. For all the details, see the separate [license](LICENSE.md) file.


## Build Instructions (Mac and Linux only)

Fletch uses the Chromium gclient tool for managing dependencies (install
[depot_tools](http://www.chromium.org/developers/how-tos/install-depot-tools) to get gclient)
and the [scons](http://www.scons.org/) build system for building.

Setup Fletch repo (assumes that you have GitHub ssh keys setup):

    $ mkdir fletch-repo
    $ gclient config git@github.com:dart-lang/fletch.git
    $ gclient sync
    $ cd fletch

Build Fletch:

    $ scons

Test Fletch:

    $ ./tools/test.py
