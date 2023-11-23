#!/bin/sh
CLM=clm

(cd backendC/CleanCompilerSources; make -f Makefile.arm)
(cd main/Unix; make -f Makefile.arm all);
$CLM -ci -fusion -I backend -I frontend -I main -I main/Unix -ABC -fusion backendconvert
$CLM -h 32M -nt -nw -ci -nr -I backend -I frontend -I main -I main/Unix \
	-IL ArgEnv \
	-l backendC/CleanCompilerSources/backend.a \
	cocl -o cocl
