module foo;

export extern(C) void foo()
{
	import core.stdc.stdio;

	printf("Hello, World!\n");
}

version (Windows) {
	import core.sys.windows.windows;
	import core.sys.windows.dll;

	extern (Windows)
	BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
	{
		switch (ulReason) {
			default: break;
			case DLL_PROCESS_ATTACH: dll_process_attach(hInstance, true); break;
			case DLL_PROCESS_DETACH: dll_process_detach(hInstance, true); break;
			case DLL_THREAD_ATTACH: dll_thread_attach(true, true); break;
			case DLL_THREAD_DETACH: dll_thread_detach(true, true); break;
		}
		return true;
	}
}
