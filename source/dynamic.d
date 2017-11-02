module dynamic;

mixin template dynamicBinding(alias mod)
{
	import core.runtime : Runtime;
	import std.traits : ReturnType, ParameterTypeTuple, functionLinkage;
	import std.format : format;

	alias _prototypes = prototypes!mod;

	private static string mixins()
	{
		string ret;
		foreach (i, proto; _prototypes) {
			ret ~= q{
				extern(%2$s) alias P_%1$s = ReturnType!(_prototypes[%3$d]) function(ParameterTypeTuple!(_prototypes[%3$d]));
				P_%1$s p_%1$s;
				extern(%2$s) ReturnType!(_prototypes[%3$d]) %1$s(ParameterTypeTuple!(_prototypes[%3$d]) params) {
					assert(p_%1$s !is null, "Function not loaded: %1$s");
					return p_%1$s(params);
				}
			}.format(__traits(identifier, proto), functionLinkage!proto, i);
		}
		return ret;
	}
	mixin(mixins());

	void loadBinding(scope string[] library_files)
	{
		import std.conv : to;
		import std.format : format;
		import std.utf : toUTF16z;
		import std.string : toStringz;
		version (Windows) import core.sys.windows.windows : LoadLibraryW;
		else import core.sys.posix.dlfcn : dlopen, RTLD_LAZY;

		foreach (f; library_files) {
			version (Windows) void* lib = LoadLibraryW(f.toUTF16z);
			else void* lib = dlopen(f.toStringz(), RTLD_LAZY);
			if (!lib) continue;

			foreach (proto; prototypes!mod) {
				mixin(q{
					p_%1$s = cast(P_%1$s)loadProc(lib, proto.mangleof);
					if (!p_%1$s)
						throw new Exception(
							format("Failed to load function '%%s' from %1$s",
							proto.mangleof));
				}.format(__traits(identifier, proto)));
			}
			return;
		}

		throw new Exception(format("Failed to load any of the shared library candidates: %(%s, %)", library_files));
	}
}

/// private
template prototypes(alias mod)
{
	import std.meta : AliasSeq, staticMap;

	alias Overloads(string name) = AliasSeq!(__traits(getOverloads, mod, name));
	alias functions = staticMap!(Overloads, AliasSeq!(__traits(allMembers, mod)));

	/*template impl(size_t idx) {
		static if (idx < members.length) {
			alias impl = AliasSeq!(members[i], impl
		} else alias impl = AliasSeq!();
	}*/
	alias prototypes = functions;
}

/// private
void* loadProc(void* lib, string name)
{
	import std.string : toStringz;

	version (Windows) {
		import core.sys.windows.windows;
		return GetProcAddress(lib, name.toStringz());
	} else {
		import core.sys.posix.dlfcn : dlsym;
		return dlsym(lib, name.toStringz());
	}
}
