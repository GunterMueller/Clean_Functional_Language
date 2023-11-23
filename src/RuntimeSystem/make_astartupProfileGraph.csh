mkdir -p linux64ProfileGraph
sed -r -f astartup.sed astartup.asm > linux64ProfileGraph/astartup.s
sed -r -f astartup.sed acopy.asm > linux64ProfileGraph/acopy.s
sed -r -f astartup.sed amark.asm > linux64ProfileGraph/amark.s
sed -r -f astartup.sed amark_prefetch.asm > linux64ProfileGraph/amark_prefetch.s
sed -r -f astartup.sed acompact.asm > linux64ProfileGraph/acompact.s
sed -r -f astartup.sed acompact_rmark.asm > linux64ProfileGraph/acompact_rmark.s
sed -r -f astartup.sed acompact_rmarkr.asm > linux64ProfileGraph/acompact_rmarkr.s
sed -r -f astartup.sed acompact_rmark_prefetch.asm > linux64ProfileGraph/acompact_rmark_prefetch.s
cp aap.s linux64ProfileGraph/aap.s
cp areals.s linux64ProfileGraph/areals.s
sed -r -f astartup.sed aprofilegraph.asm > linux64ProfileGraph/aprofilegraph.s
(cd linux64ProfileGraph; as --defsym LINUX=1 --defsym PROFILE=1 --defsym PROFILE_GRAPH=1 astartup.s -o astartup.o)
gcc -fno-pie -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -DTIME_PROFILE -DPROFILE -DPROFILE_GRAPH -ffunction-sections -fdata-sections ./scon.c -o linux64ProfileGraph/scon.o
gcc -fno-pie -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -DTIME_PROFILE -DPROFILE -DPROFILE_GRAPH -ffunction-sections -fdata-sections ./ufileIO2.c -o linux64ProfileGraph/ufileIO2.o
gcc -fno-pie -c -Ofast -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -DTIME_PROFILE -DPROFILE -DPROFILE_GRAPH -ffunction-sections -fdata-sections ./profile_graph.c -o linux64ProfileGraph/profile_graph.o
ld -r -o linux64ProfileGraph/_startupProfileGraph.o linux64ProfileGraph/astartup.o linux64ProfileGraph/scon.o afileIO3.o linux64ProfileGraph/ufileIO2.o linux64ProfileGraph/profile_graph.o
