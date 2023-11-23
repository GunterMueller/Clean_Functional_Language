mkdir -p linux64Profile
sed -r -f astartup.sed astartup.asm > linux64Profile/astartup.s
sed -r -f astartup.sed acopy.asm > linux64Profile/acopy.s
sed -r -f astartup.sed amark.asm > linux64Profile/amark.s
sed -r -f astartup.sed amark_prefetch.asm > linux64Profile/amark_prefetch.s
sed -r -f astartup.sed acompact.asm > linux64Profile/acompact.s
sed -r -f astartup.sed acompact_rmark.asm > linux64Profile/acompact_rmark.s
sed -r -f astartup.sed acompact_rmarkr.asm > linux64Profile/acompact_rmarkr.s
sed -r -f astartup.sed acompact_rmark_prefetch.asm > linux64Profile/acompact_rmark_prefetch.s
cp aap.s linux64Profile/aap.s
cp areals.s linux64Profile/areals.s
sed -r -f astartup.sed aprofile.asm > linux64Profile/aprofile.s
(cd linux64Profile; as --defsym LINUX=1 --defsym PROFILE=1 astartup.s -o astartup.o)
gcc -fno-pie -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -DTIME_PROFILE -DPROFILE -ffunction-sections -fdata-sections ./scon.c -o linux64Profile/scon.o
gcc -fno-pie -c -O -DUSE_CLIB -DLINUX -DI486 -DGNU_C -DELF -DTIME_PROFILE -DPROFILE -ffunction-sections -fdata-sections ./ufileIO2.c -o linux64Profile/ufileIO2.o
ld -r -o linux64Profile/_startupProfile.o linux64Profile/astartup.o linux64Profile/scon.o afileIO3.o linux64Profile/ufileIO2.o
