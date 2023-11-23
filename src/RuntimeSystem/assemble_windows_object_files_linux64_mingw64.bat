..\..\ml64_8.00.30806\ml64.exe /nologo /c /Fo _startup0.o _startup0.asm
..\..\ml64_8.00.30806\ml64.exe /nologo /c /Fo _startup1_.o astartup.asm
.\rename_Tn_sections_and_dINT _startup1_.o _startup1.o
..\..\ml64_8.00.30806\ml64.exe /nologo /c /DPROFILE /Fo _startup1Profile_.o astartup.asm
.\rename_Tn_sections_and_dINT _startup1Profile_.o _startup1Profile.o
..\..\ml64_8.00.30806\ml64.exe /nologo /c /DPROFILE /DPROFILE_GRAPH /Fo _startup1ProfileGraph_.o astartup.asm
.\rename_Tn_sections_and_dINT _startup1ProfileGraph_.o _startup1ProfileGraph.o
..\..\ml64_8.00.30806\ml64.exe /nologo /c /DPROFILE /DTRACE /Fo _startup1Trace_.o astartup.asm
.\rename_Tn_sections_and_dINT _startup1Trace_.o _startup1Trace.o
..\..\ml64_8.00.40904\ml64.exe /nologo /c /Fo _startup3.o afileIO3.asm
