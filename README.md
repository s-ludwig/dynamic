dynamic
=======

This is an automatic generator for runtime bindings to shared libraries/DLLs
that works based on plain static bindings consisting of - typically
`extern(C)` - function prototypes. This means that the same bindings can be
used to either link statically against a library, or to load the library at
runtime.


Example
-------

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
