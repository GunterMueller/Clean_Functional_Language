#!/bin/bash
x86_64-w64-mingw32-gcc -O rename_Tn_sections_and_dINT.c -o rename_Tn_sections_and_dINT.exe
x86_64-w64-mingw32-gcc -c -O -DWINDOWS -DTIME_PROFILE -DWRITE_HEAP wcon.c -o _startup2.o
x86_64-w64-mingw32-gcc -c -O -DWINDOWS profile_graph.c -o _startup1ProfileGraphB.o
# move include windows.h to the first line because otherwise __int64 is not defined in wcon.h
echo -e '#include <_mingw.h>\r' | cat - wfileIO3.c > wfileIO3.c_
mv wfileIO3.c_ wfileIO3.c
x86_64-w64-mingw32-gcc -c -O -DWINDOWS -DA64 -DTIME_PROFILE wfileIO3.c -o _startup4.o
