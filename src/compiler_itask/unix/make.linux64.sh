#!/bin/sh
set -e

CLM=clm

(cd backendC/CleanCompilerSources; make -f Makefile.linux64)
(cd main/Unix; make -f Makefile all);
$CLM -ci -I backend -I frontend -I main -I main/Unix -ABC -fusion backendconvert
$CLM -gcm -h 256M -s 16m -nt -nw -ci -nr -I backend -I frontend -I main -I main/Unix \
	-IL ArgEnv \
	-l backendC/CleanCompilerSources/backend.a \
	cocl -o cocl
