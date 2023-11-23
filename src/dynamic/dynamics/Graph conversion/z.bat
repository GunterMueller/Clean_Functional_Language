@cls
@set prompt=$g
rem sed -f fixed.sed <LinkedBlock2.c >LinkedBlockFixed.c
rem @if errorlevel 1 goto l
rem sed -f unfixed.sed <LinkedBlock2.c >LinkedBlockUnfixed.c
rem @if errorlevel 1 goto l
rem sed -f normal.sed <LinkedBlock2.c >LinkedBlockNormal.c
rem @if errorlevel 1 goto l
cl /nologo /EP graph_to_string.c >graph_to_string.s
@if errorlevel 1 goto l
as graph_to_string.s -o copy_graph_to_string_0x00010101.obj
@if errorlevel 1 goto l
cl /nologo /EP string_to_graph.c >string_to_graph.s
@if errorlevel 1 goto l
as string_to_graph.s -o copy_string_to_graph_0x00010101.obj
@:l
@if errorlevel 1 pause
