@echo off
goto compile%~x1
echo Do not know how to compile: %1
pause
goto end

:compile.c
:compile.C
echo gcc %1 . . .
gcc -o "..\Clean System Files\%~n1.obj" -O2 -Wall -Werror -c %1
goto end

:compile.s
:compile.S
echo as %1 . . .
as -o "..\Clean System Files\%~n1.obj" %1
goto end

:compile
echo copy %1 . . .
copy %1 "..\Clean System Files" >nul
goto end

:end
if errorlevel 1 pause


