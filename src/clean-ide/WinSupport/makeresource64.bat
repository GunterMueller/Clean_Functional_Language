Setlocal EnableDelayedExpansion
if exist "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat" (
	call "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat" amd64
) else if exist "C:\Program Files\Microsoft SDKs\Windows\v6.1\Bin\SetEnv.Cmd" (
	call "C:\Program Files\Microsoft SDKs\Windows\v6.1\Bin\SetEnv.Cmd" /x64 /Release
	color f
) else (
	call "c:\Program Files\Microsoft SDK\SetEnv.bat" /AMD64 /RETAIL
)
ml64 /c /nologo dummy64.asm
rc -r -dWIN64 winIde.rc
link /nologo /out:winIde.rsrc dummy64.obj /entry:mainCRTStartup /subsystem:console winIde.res
