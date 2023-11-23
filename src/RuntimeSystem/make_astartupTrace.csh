mkdir -p linux64Trace
sed -r -f astartup.sed astartup.asm > linux64Trace/astartup.s
sed -r -f astartup.sed acopy.asm > linux64Trace/acopy.s
sed -r -f astartup.sed amark.asm > linux64Trace/amark.s
sed -r -f astartup.sed amark_prefetch.asm > linux64Trace/amark_prefetch.s
sed -r -f astartup.sed acompact.asm > linux64Trace/acompact.s
sed -r -f astartup.sed acompact_rmark.asm > linux64Trace/acompact_rmark.s
sed -r -f astartup.sed acompact_rmarkr.asm > linux64Trace/acompact_rmarkr.s
sed -r -f astartup.sed acompact_rmark_prefetch.asm > linux64Trace/acompact_rmark_prefetch.s
cp aap.s linux64Trace/aap.s
cp areals.s linux64Trace/areals.s
sed -r -f astartup.sed atrace.asm > linux64Trace/atrace.s
(cd linux64Trace; as --defsym LINUX=1 --defsym PROFILE=1 --defsym TRACE=1 astartup.s -o astartup.o)
gcc -fno-pie -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -DTIME_PROFILE -DPROFILE -DTRACE -ffunction-sections -fdata-sections ./scon.c -o linux64Trace/scon.o
gcc -fno-pie -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -DTIME_PROFILE -DPROFILE -DTRACE -ffunction-sections -fdata-sections ./ufileIO2.c -o linux64Trace/ufileIO2.o
ld -r -o linux64Trace/_startupTrace.o linux64Trace/astartup.o linux64Trace/scon.o afileIO3.o linux64Trace/ufileIO2.o
