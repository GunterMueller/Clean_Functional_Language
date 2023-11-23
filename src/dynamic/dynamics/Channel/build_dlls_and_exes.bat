cd ClientChannel
cl /nologo /c /O channel.c
cl /nologo /c /O select_dynamic_linker_folder.c
cl /nologo /c /O ..\Utilities\Util.c
cl /nologo /c /O ..\DynamicLink\utilities.c
if not defined VisualStudioVersion (
	link /nologo channel.obj select_dynamic_linker_folder.obj Util.obj utilities.obj kernel32.lib user32.lib gdi32.lib advapi32.lib shell32.lib ole32.lib /dll /out:ClientChannel.dll
) else if VisualStudioVersion GEQ 14.0 (
	link /nologo channel.obj select_dynamic_linker_folder.obj Util.obj utilities.obj kernel32.lib user32.lib gdi32.lib advapi32.lib shell32.lib ole32.lib legacy_stdio_definitions.lib /dll /out:ClientChannel.dll
) else (
	link /nologo channel.obj select_dynamic_linker_folder.obj Util.obj utilities.obj kernel32.lib user32.lib gdi32.lib advapi32.lib shell32.lib ole32.lib /dll /out:ClientChannel.dll
)
cd ..
cd DynamicLink
cl /nologo /c /O DynamicLink.c
cl /nologo /c /O global.c
cl /nologo /c /O interface.c
cl /nologo /c /O server.c
cl /nologo /c /O serverblock.c
cl /nologo /c /O ..\Utilities\Util.c
cl /nologo /c /O utilities.c
cl /nologo /c /O channel_for_dynamic_link.c
if not defined VisualStudioVersion (
	link /nologo DynamicLink.obj global.obj interface.obj server.obj serverblock.obj channel_for_dynamic_link.obj Util.obj utilities.obj kernel32.lib user32.lib gdi32.lib advapi32.lib /dll /out:DynamicLink.dll
) else if VisualStudioVersion GEQ 14.0 (
	link /nologo DynamicLink.obj global.obj interface.obj server.obj serverblock.obj channel_for_dynamic_link.obj Util.obj utilities.obj kernel32.lib user32.lib gdi32.lib advapi32.lib legacy_stdio_definitions.lib /dll /out:DynamicLink.dll
) else (
	link /nologo DynamicLink.obj global.obj interface.obj server.obj serverblock.obj channel_for_dynamic_link.obj Util.obj utilities.obj kernel32.lib user32.lib gdi32.lib advapi32.lib /dll /out:DynamicLink.dll
)
cd ..
