#!/bin/sh
set -e

CLM=clm

(cd backendC/CleanCompilerSources; make)
(cd main/Unix; CFLAGS=-m32 make -f Makefile all);
$CLM -ci -I backend -I frontend -I main -I main/Unix -ABC -fusion backendconvert
$CLM -gcm -h 40M -s 2m -nt -nw -ci -nr -I backend -I frontend -I main -I main/Unix \
	-IL ArgEnv \
	-l backendC/CleanCompilerSources/backend.a \
	-l -m32 \
	cocl -o cocl
