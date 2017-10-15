module dynamic;

mixin template dynamicBinding(alias mod)
{
	import core.runtime : Runtime;
	import std.traits : ReturnType, ParameterTypeTuple, functionLinkage;
	import std.format : format;

	static foreach (proto; prototypes!mod) {
		alias R = ReturnType!proto;
		alias P = ParameterTypeTuple!proto;
		mixin(q{
				extern(%2$s) alias P_%1$s = R function(P);
				P_%1$s p_%1$s;
				extern(%2$s) R %1$s(P params) {
					assert(p_%1$s !is null, "Function not loaded: %1$s");
					return p_%1$s(params);
				}
		}.format(__traits(identifier, proto), functionLinkage!proto));
	}

	void loadBinding(scope string[] library_files)
	{
		import std.format : format;

		foreach (f; library_files) {
			auto lib = Runtime.loadLibrary(f);
			if (!lib) continue;

			foreach (proto; prototypes!mod) {
				mixin(q{
					p_%1$s = cast(P_%1$s)loadProc(lib, proto.mangleof);
					if (!p_%1$s)
						throw new Exception(
							format("Failed to load function '%s' from %1$s",
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
	} else version (OSX) {
		return dlsym(lib, name.toStringz());
	} else {
		return dlsym(lib, name.toStringz());
	}
}
