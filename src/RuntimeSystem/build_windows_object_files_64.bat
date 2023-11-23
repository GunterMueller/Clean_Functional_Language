call "c:\Program Files\Microsoft SDK\SetEnv.bat" /AMD64 /RETAIL
cl /nologo /O rename_Tn_sections_and_dINT.c
ml64 /nologo /c /Fo _startup0.o _startup0.asm
ml64 /nologo /c /Fo _startup1_.o astartup.asm
.\rename_Tn_sections_and_dINT _startup1_.o _startup1.o
ml64 /nologo /c /DPROFILE /Fo _startup1Profile_.o astartup.asm
.\rename_Tn_sections_and_dINT _startup1Profile_.o _startup1Profile.o
ml64 /nologo /c /DPROFILE /DPROFILE_GRAPH /Fo _startup1ProfileGraph_.o astartup.asm
.\rename_Tn_sections_and_dINT _startup1ProfileGraph_.o _startup1ProfileGraph.o
ml64 /nologo /c /DPROFILE /DTRACE /Fo _startup1Trace_.o astartup.asm
.\rename_Tn_sections_and_dINT _startup1Trace_.o _startup1Trace.o
cl /nologo /c /O /DWINDOWS /DTIME_PROFILE /DWRITE_HEAP /Fo_startup2.o wcon.c
"C:\Program Files (x86)\Microsoft Visual Studio 8\VC\bin\x86_amd64\ml64.exe" /nologo /c /Fo _startup3.o afileIO3.asm
cl /nologo /c /O /DWINDOWS /DA64 /DTIME_PROFILE /Fo_startup4.o wfileIO3.c
