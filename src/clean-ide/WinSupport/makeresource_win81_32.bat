"C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\ml.exe" /c /nologo dummy.asm
"C:\Program Files (x86)\Windows Kits\8.1\bin\x86\rc.exe" -r -dWIN32 winIde.rc
"C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\link.exe" -out:winIde.rsrc /subsystem:console dummy.obj winIde.res
