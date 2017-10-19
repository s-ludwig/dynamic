dynamic
=======

This is an automatic generator for runtime bindings to shared libraries/DLLs
that works based on plain static bindings consisting of - typically
`extern(C)` - function prototypes. This means that the same bindings can be
used to either link statically against a library, or to load the library at
runtime.

Example
-------

```
import std.stdio : writefln;
import deimos.zmq.zmq;
import dynamic;

// generates the trampoline functions that forward to
// the API entry points loaded at runtime
mixin dynamicBinding!(deimos.zmq.zmq) _zmq;

void main()
{
	// load all API functions from the shared library
	version (Windows) enum libs = ["zmq.dll"];
	else enum libs = ["libzmq.so"];
	_zmq.loadBinding(libs);

	// start to use the API as usual
	auto context = zmq_ctx_new();
	auto sock = zmq_socket(context, ZMQ_REP);
	int rc = zmq_bind(sock, "tcp://*:5555");
	assert(rc == 0);

	ubyte[10] buf;
	auto len = zmq_recv(sock, buf.ptr, buf.length, 0);
	writefln(Received: %s", buf[0 .. len]);
}
```


Testing the included example project
------------------------------------

First, build the example library:

	cd example
	dub build :foo

This will create a dynamic/shared library in the foo/ sub folder. Afterwards,
build and run the example itself:

	dub

This will load the generated dynamic library at runtime and will then calls the
exported `foo` function. Note how the `foo_binding.d` file defines just a static
function prototype, which could just as well be used to statically link against
the library.
