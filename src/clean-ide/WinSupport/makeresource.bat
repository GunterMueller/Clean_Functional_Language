call "c:\Program Files\Microsoft SDK\SetEnv.bat" /XP32 /RETAIL

"C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\bin\ml.exe" /c /nologo dummy.asm
rc -r -dWIN32 winIde.rc
link -out:winIde.rsrc /subsystem:console dummy.obj winIde.res
