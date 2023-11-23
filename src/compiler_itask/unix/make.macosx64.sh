#!/bin/sh
set -e

CLM=clm

(cd backendC/CleanCompilerSources; make -f Makefile.linux64)
(cd main/Unix; make -f Makefile all);
$CLM -gcm -h 256M -s 16m -nt -nw -ci -nr -IL ArgEnv -IL StdLib -IL Dynamics -I backend -I frontend -I main -I main/Unix \
	-l backendC/CleanCompilerSources/backend.a \
	cocl -o cocl
