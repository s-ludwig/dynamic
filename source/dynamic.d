module dynamic;

enum SymbolSet { all, skipDeprecated }


/** Declares a dynamically linked library binding.

	Params:
		mod = Alias of a module that contains a static binding consisting of
			function prototypes
		symbols = Optionally disables binding of deprecated symbols

	Example:
		---
		import dynamic;

		import my_c_library : myCLibFunction;

		// define the dynamic binding
		dynamicBinding!my_c_library myCLibBinding;

		void main()
		{
			// load the actual symbols from the dynamic library
			version (Windows) myCLibBinding.loadBinding(["myclib.dll"]);
			else version (OSX) myCLibBinding.loadBinding(["libmyclib.dylib"]);
			else myCLibBinding.loadBinding(["libmyclib.so", "libmyclib.so.1"]);

			// now we can call a function from `my_c_library` as if it were a
			// simple statically linked function:
			myCLibFunction();
		}
		---
*/
mixin template dynamicBinding(alias mod, SymbolSet symbols = SymbolSet.all)
{
	import core.runtime : Runtime;
	import std.array : join;
	import std.traits : ReturnType, ParameterTypeTuple, functionLinkage;

	alias _prototypes = prototypes!(mod, symbols);
	private enum _id(alias p) = __traits(identifier, p);

	static foreach (i, proto; _prototypes) {
		mixin("extern("~functionLinkage!proto~") alias P_"~_id!proto~" = ReturnType!proto function(ParameterTypeTuple!proto) " ~ join([__traits(getFunctionAttributes, proto)], " ") ~ ";");
		mixin("P_"~_id!proto~" p_"~_id!proto~";");
		mixin("extern("~functionLinkage!proto~") ReturnType!proto "~_id!proto~"(ParameterTypeTuple!proto params"~(__traits(getFunctionVariadicStyle, proto) == "none"
				? "" : ", ...")~") "~join([__traits(getFunctionAttributes, proto)], " ")~" {\n"
			~ "  assert(p_"~_id!proto~" !is null, \"Function not loaded: "~_id!proto~"\");\n"
			~ "  return p_"~_id!proto~"(params);\n"
			~ "}");
	}

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

			foreach (proto; _prototypes) {
				enum ident = __traits(identifier, proto);
				mixin("p_"~ident) = cast(typeof(mixin("p_"~ident)))loadProc(lib, proto.mangleof);
				if (!mixin("p_"~ident))
					throw new Exception("Failed to load function '"~proto.mangleof~"' from " ~ f);
			}
			return;
		}

		throw new Exception(format("Failed to load any of the shared library candidates: %(%s, %)", library_files));
	}
}

/// private
template prototypes(alias mod, SymbolSet symbols)
{
	import std.meta : AliasSeq, staticMap;

	template Overloads(string name) {
		static if (symbols == SymbolSet.skipDeprecated && isDeprecated!(mod, name))
			alias Overloads = AliasSeq!();
		else
			alias Overloads = AliasSeq!(__traits(getOverloads, mod, name));
	}
	alias functions = staticMap!(Overloads, AliasSeq!(__traits(allMembers, mod)));

	/*template impl(size_t idx) {
		static if (idx < members.length) {
			alias impl = AliasSeq!(members[i], impl
		} else alias impl = AliasSeq!();
	}*/
	alias prototypes = functions;
}

// crude workaround to gag deprecation warnings
private enum isDeprecated(alias parent, string symbol) =
	!__traits(compiles, {
		static assert(!__traits(isDeprecated, __traits(getMember, parent, symbol)));
	});

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
