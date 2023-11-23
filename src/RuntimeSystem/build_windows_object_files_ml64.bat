Setlocal EnableDelayedExpansion
if exist "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat" (
	call "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat" amd64
) else if exist "C:\Program Files\Microsoft SDKs\Windows\v6.1\Bin\SetEnv.Cmd" (
	call "C:\Program Files\Microsoft SDKs\Windows\v6.1\Bin\SetEnv.Cmd" /x64 /Release
	color f
) else (
	call "c:\Program Files\Microsoft SDK\SetEnv.bat" /AMD64 /RETAIL
)
mkdir ml64
sed -r -f astartup_ml64.sed < astartup.asm > ml64\astartup.asm
sed -r -f astartup_ml64.sed < acopy.asm > ml64\acopy.asm
sed -r -f astartup_ml64.sed < amark.asm > ml64\amark.asm
sed -r -f astartup_ml64.sed < amark_prefetch.asm > ml64\amark_prefetch.asm
sed -r -f astartup_ml64.sed < acompact.asm > ml64\acompact.asm
sed -r -f astartup_ml64.sed < acompact_rmark.asm > ml64\acompact_rmark.asm
sed -r -f astartup_ml64.sed < acompact_rmark_prefetch.asm > ml64\acompact_rmark_prefetch.asm
sed -r -f astartup_ml64.sed < acompact_rmarkr.asm > ml64\acompact_rmarkr.asm
copy /y areals.asm ml64\areals.asm
sed -r -f astartup_ml64.sed < aap.asm > ml64\aap.asm
copy /y aprofile.asm ml64\aprofile.asm
copy /y aprofilegraph.asm ml64\aprofilegraph.asm
copy /y atrace.asm ml64\atrace.asm
cl /nologo /O rename_Tn_sections_and_dINT.c
ml64 /nologo /c /Fo _startup0.o _startup0.asm
cd ml64
ml64 /nologo /c /Fo ..\_startup1_.o astartup.asm
cd ..
.\rename_Tn_sections_and_dINT _startup1_.o _startup1.o
cd ml64
ml64 /nologo /c /DPROFILE /Fo ..\_startup1Profile_.o astartup.asm
cd ..
.\rename_Tn_sections_and_dINT _startup1Profile_.o _startup1Profile.o
cd ml64
ml64 /nologo /c /DPROFILE /DPROFILE_GRAPH /Fo ..\_startup1ProfileGraph_.o astartup.asm
cd ..
.\rename_Tn_sections_and_dINT _startup1ProfileGraph_.o _startup1ProfileGraph.o
cl /nologo /TC /c /GS- /GR- /EHs-c- /O /DWINDOWS /Fo_startup1ProfileGraphB.o profile_graph.c
cd ml64
ml64 /nologo /c /DPROFILE /DTRACE /Fo..\_startup1Trace_.o astartup.asm
cd ..
.\rename_Tn_sections_and_dINT _startup1Trace_.o _startup1Trace.o
cl /nologo /TC /c /GS- /GR- /EHs-c- /O /DWINDOWS /DTIME_PROFILE /DWRITE_HEAP /Fo_startup2.o wcon.c
ml64 /nologo /c /Fo _startup3.o afileIO3.asm
cl /nologo /TC /c /GS- /GR- /EHs-c- /O /DWINDOWS /DA64 /DTIME_PROFILE /Fo_startup4.o wfileIO3.c
