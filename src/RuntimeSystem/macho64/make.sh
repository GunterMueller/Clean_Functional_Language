as startup.s -o startup.o
as startupTrace.s -o startupTrace.o
as startupProfile.s -o startupProfile.o
as startupProfileGraph.s -o startupProfileGraph.o
(cd ..; gcc -c -O -DI486 -DMACH_O64 scon.c -o scon.o)
(cd ..; gcc -c -O -DI486 -DMACH_O64 -DTIME_PROFILE -DPROFILE scon.c -o scon-profile.o)
(cd ..; gcc -c -O -DI486 -DMACH_O64 -DTIME_PROFILE -DPROFILE -DPROFILE_GRAPH scon.c -o scon-profile-graph.o)
(cd ..; gcc -c -O -DI486 -DMACH_O64 -DTIME_PROFILE -DPROFILE -DTRACE scon.c -o scon-trace.o)
(cd ..; gcc -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DMACH_O64 -o macho64/ufileIO2.o ./ufileIO2.c)
(cd ..; gcc -c -g -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DMACH_O64 -o macho64/profile_graph.o ./profile_graph.c)
as afileIO3.s -o afileIO3.o
# Because of a bug in ld, the following does not work anymore (MacOSX 10.7 and 10.8)
# ld -r startup.o ../scon.o afileIO3.o ufileIO2.o -o _startup.o
libtool -static -o _startup.o startup.o ../scon.o afileIO3.o ufileIO2.o
# Because of a bug in ld, the following does not work anymore (MacOSX 10.7 and 10.8)
# ld -r startupTrace.o ../scon-trace.o afileIO3.o ufileIO2.o -o _startupTrace.o
libtool -static -o _startupTrace.o startupTrace.o ../scon-trace.o afileIO3.o ufileIO2.o
# Because of a bug in ld, the following does not work anymore (MacOSX 10.7 and 10.8)
# ld -r startupProfile.o ../scon-profile.o afileIO3.o ufileIO2.o -o _startupProfile.o
libtool -static -o _startupProfile.o startupProfile.o ../scon-profile.o afileIO3.o ufileIO2.o
libtool -static -o _startupProfileGraph.o startupProfileGraph.o ../scon-profile-graph.o afileIO3.o ufileIO2.o profile_graph.o
