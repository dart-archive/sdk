# Fletch

Fletch is an experimental system that makes it possible to implement highly concurrent programs
in the Dart programming language. To make it easier to reason about such programs, Fletch comes with a
virtual machine implementation that encourages synchronous operations over asynchronous ones - and 
enables lots of user-level threads to be blocked without holding on to too many resources.

Fletch is very much incomplete. We'd be very happy to hear about things that work well and areas that need 
more work, but don't expect to be able to build products on top of it.
