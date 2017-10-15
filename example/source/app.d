import foo_binding;
import dynamic;

/// Generates the necessary glue code to the DLL/so
mixin dynamicBinding!foo_binding _foo;

void main()
{
	version(Windows) enum libs = ["foo/foo.dll"];
	else version (OSX) enum libs = ["foo/libfoo.so"];
	else enum libs = ["foo/libfoo.so"];
	_foo.loadBinding(libs);

	foo();
}
