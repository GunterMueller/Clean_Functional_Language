mkdir -p linux64
sed -r -f astartup.sed astartup.asm > linux64/astartup.s
sed -r -f astartup.sed acopy.asm > linux64/acopy.s
sed -r -f astartup.sed amark.asm > linux64/amark.s
sed -r -f astartup.sed amark_prefetch.asm > linux64/amark_prefetch.s
sed -r -f astartup.sed acompact.asm > linux64/acompact.s
sed -r -f astartup.sed acompact_rmark.asm > linux64/acompact_rmark.s
sed -r -f astartup.sed acompact_rmarkr.asm > linux64/acompact_rmarkr.s
sed -r -f astartup.sed acompact_rmark_prefetch.asm > linux64/acompact_rmark_prefetch.s
cp aap.s linux64/aap.s
cp areals.s linux64/areals.s
(cd linux64; as --defsym LINUX=1 astartup.s -o astartup.o)
as afileIO3.s -o afileIO3.o
gcc -fno-pie -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -ffunction-sections -fdata-sections -o linux64/ufileIO2.o ./ufileIO2.c
gcc -fno-pie -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -ffunction-sections -fdata-sections ./scon.c -o linux64/scon.o
ld -r -o linux64/_startup.o linux64/astartup.o linux64/scon.o afileIO3.o linux64/ufileIO2.o
