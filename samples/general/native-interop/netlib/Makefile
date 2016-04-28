CC=gcc
LIBDIR=../../../bin/
LIBNAME=netlib

# OS detection needed to produce expected dynamic library.
uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')
ifeq ($(uname_S),Darwin)
  DYNLIBNAME = lib$(LIBNAME).dylib
  DYNLIBOPTIONS = -dynamiclib
else
  DYNLIBNAME = lib$(LIBNAME).so
  DYNLIBOPTIONS = -shared
endif

main: netlib.c main.c
	# netlib library.
	$(CC) -c netlib.c
	$(CC) -current_version 1.0 $(DYNLIBOPTIONS) netlib.o -o $(DYNLIBNAME)
	cp $(DYNLIBNAME) $(LIBDIR)
	# netlib main program.
	$(CC) -c main.c
	$(CC) -v main.o ./libnetlib.dylib -o main

.PHONY: clean
clean:
	rm -f *.o
	rm -f main
	rm -f *.dylib
